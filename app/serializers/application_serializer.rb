# frozen_string_literal: true

class ApplicationSerializer
  include JSONAPI::Serializer

  def self.utc_microsecond_timestamps(*attributes)
    attributes.each do |attribute_name|
      attribute attribute_name do |record|
        value = record.public_send(attribute_name)
        next if value.nil?

        utc = value.utc
        fraction = utc.usec.zero? ? "" : format(".%06d", utc.usec)
        "#{utc.strftime('%Y-%m-%dT%H:%M:%S')}#{fraction}+00:00"
      end
    end
  end
end
