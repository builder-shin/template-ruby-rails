# frozen_string_literal: true

require "simpleidn"
require "json"

module Auth
  # EmailStr syntax plus the frozen reference Unicode and IDNA2008 validity profile.
  module EmailIdentity
    UNICODE = JSON.parse(File.read(File.join(__dir__, "email_unicode.json"))).freeze
    SPACE = /[\p{Space}\u001c-\u001f]/
    NAME = /[\p{L}\p{N}_!\#$%&'*+\-\/=?^`{|}~]/
    PRETTY = /\A#{SPACE}*(?:(?:#{NAME}+#{SPACE}+)*#{NAME}+|"(?:[^"\r\n]|\\")+")?#{SPACE}*<(.+)>#{SPACE}*\z/
    LOCAL = /\A[a-zA-Z0-9!\#$%&'*+\-\/=?^_`{|}~.\u0080-\u{10ffff}]+\z/
    HOST = /\A[a-zA-Z0-9.\-\u0080-\u{10ffff}]+\z/
    RESERVED = /(?:\A|\.)(?:arpa|invalid|local|localhost|onion|test)\z/

    def self.normalize(value)
      raise ArgumentError, "invalid email" unless value.is_a?(String) && value.length <= 2048

      raw = (PRETTY.match(value)&.[](1) || value).gsub(/\A#{SPACE}+|#{SPACE}+\z/, "")
      local, domain, extra = raw.split("@", -1)
      raise ArgumentError, "invalid email" if extra || !local || !domain || !LOCAL.match?(local) || !HOST.match?(domain)
      raise ArgumentError, "unsafe email" unless safe?(local) && safe?(domain)
      raise ArgumentError, "invalid dot atom" if local.start_with?(".") || local.end_with?(".") || local.include?("..")

      mapped = uts46_map(domain)
      raise ArgumentError, "invalid domain" unless HOST.match?(mapped) && safe?(mapped)
      labels = mapped.split(".", -1).map do |label|
        raise ArgumentError, "empty domain label" if label.empty?
        if label.start_with?("xn--")
          raise ArgumentError, "invalid punycode" if label.end_with?("-")
          decoded = SimpleIDN::Punycode.decode(label.delete_prefix("xn--"))
          raise ArgumentError, "noncanonical punycode" unless "xn--" + SimpleIDN::Punycode.encode(decoded) == label
          decoded
        else
          label
        end
      end
      labels.each { |label| validate_label!(label) }
      unicode = labels.join(".")
      ascii = labels.map { |label| label.ascii_only? ? label : "xn--" + SimpleIDN::Punycode.encode(label) }.join(".")
      unless ascii.include?(".") && /[a-z]\z/i.match?(ascii) && !RESERVED.match?(ascii) &&
          ascii.split(".", -1).all? { |label| label.length.between?(1, 63) && !label.start_with?("-") && !label.end_with?("-") }
        raise ArgumentError, "invalid domain"
      end
      raise ArgumentError, "unsafe domain" unless safe?(unicode)

      nfc = local.unicode_normalize(:nfc)
      unless LOCAL.match?(nfc) && safe?(nfc) && !nfc.start_with?(".") && !nfc.end_with?(".") && !nfc.include?("..")
        raise ArgumentError, "invalid normalized local part"
      end
      normalized = "#{nfc}@#{unicode}"
      raise ArgumentError, "email exceeds 254 bytes" if [ raw, normalized, "#{nfc}@#{ascii}" ].any? { |address| address.bytesize > 254 }

      identity = normalized.downcase(:fold)
      raise ArgumentError, "email exceeds storage length" if identity.length > 254

      identity
    rescue SimpleIDN::ConversionError, EncodingError
      raise ArgumentError, "invalid IDNA domain"
    end

    def self.in_ranges?(character, ranges)
      return false unless character
      point = character.ord
      range = ranges.bsearch { |entry| entry[1] > point }
      range && range[0] <= point
    end

    def self.uts46_map(value)
      rows = UNICODE.fetch("uts46")
      value.each_char.map do |character|
        following = rows.bsearch_index { |row| row[0] > character.ord }
        row = rows[following ? following - 1 : -1]
        case row[1]
        when "V", "D" then character
        when "M" then row[2]
        when "3" then row[2] || character
        when "I" then ""
        else raise ArgumentError, "invalid UTS46 codepoint"
        end
      end.join.unicode_normalize(:nfc)
    end

    def self.safe?(value)
      value.each_char.none? { |character| in_ranges?(character, UNICODE.fetch("unsafe")) } &&
        !in_ranges?(value[0], UNICODE.fetch("marks"))
    end

    def self.validate_label!(label)
      unless safe?(label) && label == label.unicode_normalize(:nfc) &&
          !label.start_with?("-") && !label.end_with?("-") && label[2, 2] != "--"
        raise ArgumentError, "invalid IDNA label"
      end
      label.each_char.with_index do |character, index|
        next if in_ranges?(character, UNICODE.fetch("pvalid"))
        valid = case character
        when "\u00b7" then index.positive? && label[index - 1] == "l" && label[index + 1] == "l"
        when "\u0375" then /\p{Greek}/.match?(label[index + 1].to_s)
        when "\u05f3", "\u05f4" then index.positive? && /\p{Hebrew}/.match?(label[index - 1])
        when "\u30fb" then /[\p{Hiragana}\p{Katakana}\p{Han}]/.match?(label.delete(character))
        when /[\u0660-\u0669]/ then !/[\u06f0-\u06f9]/.match?(label)
        when /[\u06f0-\u06f9]/ then !/[\u0660-\u0669]/.match?(label)
        else false
        end
        raise ArgumentError, "invalid IDNA codepoint or context" unless valid
      end
      directions = label.each_char.map { |character| UNICODE.fetch("bidi").find { |_name, ranges| in_ranges?(character, ranges) }&.first }
      return unless directions.any? { |direction| %w[R AL AN].include?(direction) }
      rtl = %w[R AL].include?(directions.first)
      raise ArgumentError, "invalid bidi start" unless rtl || directions.first == "L"
      allowed = rtl ? %w[R AL AN EN ES CS ET ON BN NSM] : %w[L EN ES CS ET ON BN NSM]
      ending = directions.reverse.find { |direction| direction != "NSM" }
      endings = rtl ? %w[R AL EN AN] : %w[L EN]
      unless directions.all? { |direction| allowed.include?(direction) } && endings.include?(ending) &&
          !(rtl && directions.include?("AN") && directions.include?("EN"))
        raise ArgumentError, "invalid bidi label"
      end
    end
    private_class_method :safe?, :in_ranges?, :validate_label!, :uts46_map
  end
end
