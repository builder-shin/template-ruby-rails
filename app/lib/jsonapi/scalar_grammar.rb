# frozen_string_literal: true

require "date"
require "time"

module Jsonapi
  # Match the public Python scalar grammar before binding values to PostgreSQL.
  module ScalarGrammar
    module_function

    def decimal_digits(raw)
      raw.gsub(/\p{Nd}/) do |character|
        code = character.ord
        start = code
        start -= 1 while /\p{Nd}/.match?((start - 1).chr(Encoding::UTF_8))
        ((code - start) % 10).to_s
      end
    end

    def integer(raw)
      ascii = decimal_digits(raw).gsub(/\A\p{Space}+|\p{Space}+\z/, "")
      raise ArgumentError unless /\A[+-]?[0-9](?:_?[0-9])*\z/.match?(ascii)

      Integer(ascii.delete("_"), 10)
    end

    def uuid(raw)
      candidate = decimal_digits(raw.gsub("urn:", "").gsub("uuid:", "").gsub(/\A[{}]+|[{}]+\z/, "").delete("-"))
      raise ArgumentError unless candidate.length == 32

      integer = candidate.gsub(/\A\p{Space}+|\p{Space}+\z/, "")
      raise ArgumentError unless /\A[+]?(?:0x_?)?[0-9a-f](?:_?[0-9a-f])*\z/i.match?(integer)

      hex = Integer(integer, 16).to_s(16).rjust(32, "0")

      [ hex[0, 8], hex[8, 4], hex[12, 4], hex[16, 4], hex[20, 12] ].join("-").downcase
    end

    def clock(raw)
      match = /\A(\d{2})(?:(:?)(\d{2})(?:\2(\d{2}))?)?(?:[.,](\d+))?\z/.match(raw)
      raise ArgumentError unless match

      [ match[1].to_i * 3600 + match[3].to_i * 60 + match[4].to_i, match[5].to_s[0, 6].ljust(6, "0").to_i ]
    end

    def timestamp(raw)
      match = /\A(?:(\d{4})(-?)(\d{2})\2(\d{2})|(\d{4})(-?)W(\d{2})(?:\6([1-7]))?)(.)(.+)\z/m.match(raw)
      raise ArgumentError unless match

      date = if match[1]
        Date.new(match[1].to_i, match[3].to_i, match[4].to_i, Date::GREGORIAN)
      else
        Date.commercial(match[5].to_i, match[7].to_i, (match[8] || "1").to_i, Date::GREGORIAN)
      end
      raise ArgumentError unless (1..9999).cover?(date.year)

      time = /\A(.*?)(Z|[+-].+)\z/m.match(match[10])
      raise ArgumentError unless time

      local_seconds, local_micros = clock(time[1])
      parts = /\A(\d{2})(?::?(\d{2}))?(?::?(\d{2}))?/.match(time[1])
      raise ArgumentError if parts[1].to_i > 23 || parts[2].to_i > 59 || parts[3].to_i > 59

      zone = time[2]
      offset_seconds, offset_micros = zone == "Z" ? [ 0, 0 ] : clock(zone[1..])
      raise ArgumentError if offset_seconds >= 86400

      offset = offset_seconds + Rational(offset_micros, 1_000_000)
      offset = -offset if zone.start_with?("-")
      utc = Time.utc(date.year, date.month, date.day) + local_seconds + Rational(local_micros, 1_000_000) - offset
      raise ArgumentError unless (1..9999).cover?(utc.year)

      utc
    end
  end
end
