Rswag::Api.configure do |c|
  c.openapi_root = Rails.root.to_s + "/swagger"
  c.swagger_filter = ->(swagger, env) { process_swagger(swagger, env) }
end

def process_swagger(swagger, env)
  paths = swagger["paths"]

  paths&.each do |path, methods|
    methods.each do |method, details|
      if details["responses"]
        new_responses = {}
        order = 1
        previous_key_base = nil

        details["responses"].each do |key, value|
          key_base = key.split("{division}")[0]

          if key_base != previous_key_base
            order = 1
          else
            order += 1
          end

          new_key = "#{key_base} - #{order}"
          new_responses[new_key] = value
          previous_key_base = key_base
        end

        details["responses"] = new_responses
      end
    end
  end
end
