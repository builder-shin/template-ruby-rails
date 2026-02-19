# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  config.openapi_root = Rails.root.join('swagger').to_s

  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'API Document',
        version: 'v1'
      },
      paths: {},
      servers: [
        {
          url: 'https://{defaultHost}',
          variables: {
            defaultHost: {
              default: 'localhost'
            }
          }
        }
      ]
    }
  }

  config.openapi_format = :yaml

  def jsonapi_schema(schema)
    {
      type: 'object',
      properties: {
        data: {
          type: 'object',
          properties: {
            type: { type: 'string' },
            id: { type: 'string' },
            attributes: schema
          }
        }
      }
    }
  end

  def jsonapi_body(data)
    {
      data: {
        attributes: data
      }
    }
  end

  config.after do |example|
    next unless example.metadata[:response].present?
    example.metadata[:response][:code] += "{division}#{example.metadata[:full_description]}"
    content = example.metadata[:response][:content] || {}
    example_spec = {
      "application/json"=>{
        examples: {
          response: {
            value: JSON.parse(response.body, symbolize_names: true)
          }
        }
      }
    }
    example.metadata[:response][:content] = content.deep_merge(example_spec)
    # generate_response_schema(example, response) if respond_to?(:response)
  end

  def expect_response_to_raise_error(response, error)
    expect(JSON.parse(response.body)['errors'][0]['title']).to eq(error)
  end
end
