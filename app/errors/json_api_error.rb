# frozen_string_literal: true

class JsonApiError < StandardError
  attr_reader :status, :code, :source, :context

  def initialize(status:, code:, source: nil, context: {})
    @status = Integer(status)
    @code = code.to_s.freeze
    @source = source&.to_h&.symbolize_keys&.slice(:pointer, :parameter)&.freeze
    @context = context.to_h.symbolize_keys.freeze

    raise ArgumentError, "status must be an HTTP error status" unless (400..599).cover?(@status)

    super(@code)
  end
end
