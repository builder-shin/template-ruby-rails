# frozen_string_literal: true

require "rails_helper"

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  config.openapi_root = Rails.root.join("swagger").to_s

  identifier_schema = lambda do |type|
    {
      type: "object",
      required: %w[type id],
      properties: {
        type: { type: "string", enum: [ type ] },
        id: { type: "string", format: "uuid" }
      }
    }
  end
  document_response = lambda do |schema|
    {
      description: "JSON:API document",
      content: {
        "application/vnd.api+json" => {
          schema: { "$ref" => "#/components/schemas/#{schema}" }
        }
      }
    }
  end
  request_body = lambda do |schema|
    {
      required: true,
      content: {
        "application/vnd.api+json" => {
          schema: { "$ref" => "#/components/schemas/#{schema}" }
        }
      }
    }
  end
  operation = lambda do |summary, response_schema = nil, status: "200", protected: false, request_schema: nil|
    response = response_schema ? document_response.call(response_schema) : { description: "No Content" }
    definition = { summary: summary, responses: { status => response } }
    definition[:security] = [ { BearerAuth: [] } ] if protected
    definition[:requestBody] = request_body.call(request_schema) if request_schema
    definition
  end
  id_parameter = {
    name: "id",
    in: "path",
    required: true,
    schema: { type: "string", format: "uuid" }
  }
  upsert_operation = operation.call(
    "Example 생성 또는 전체 교체",
    "ExampleDocument",
    protected: true,
    request_schema: "ExampleReplaceDocument"
  )
  upsert_operation[:responses]["201"] = document_response.call("ExampleDocument")

  config.openapi_specs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.1",
      info: {
        title: "Template Ruby Rails Example API",
        version: "v1"
      },
      servers: [ { url: "http://localhost:4000" } ],
      paths: {
        "/api/v1/examples" => {
          get: operation.call("Example 목록 조회", "ExampleCollectionDocument"),
          post: operation.call(
            "Example 생성",
            "ExampleDocument",
            status: "201",
            protected: true,
            request_schema: "ExampleCreateDocument"
          )
        },
        "/api/v1/examples/{id}" => {
          parameters: [ id_parameter ],
          get: operation.call("Example 조회", "ExampleDocument"),
          patch: operation.call(
            "Example 일부 수정",
            "ExampleDocument",
            protected: true,
            request_schema: "ExamplePatchDocument"
          ),
          put: upsert_operation,
          delete: operation.call("Example 삭제", status: "204", protected: true)
        },
        "/api/v1/examples/{id}/relationships/category" => {
          parameters: [ id_parameter ],
          get: operation.call("Category linkage 조회", "CategoryRelationshipDocument"),
          patch: operation.call(
            "Category 관계 교체",
            status: "204",
            protected: true,
            request_schema: "CategoryRelationshipDocument"
          )
        },
        "/api/v1/examples/{id}/category" => {
          parameters: [ id_parameter ],
          get: operation.call("Category related resource 조회", "CategoryDocument")
        },
        "/api/v1/examples/{id}/relationships/tags" => {
          parameters: [ id_parameter ],
          get: operation.call("Tag linkage 조회", "TagsRelationshipDocument"),
          post: operation.call(
            "Tag 관계 추가",
            status: "204",
            protected: true,
            request_schema: "TagsRelationshipDocument"
          ),
          patch: operation.call(
            "Tag 관계 교체",
            status: "204",
            protected: true,
            request_schema: "TagsRelationshipDocument"
          ),
          delete: operation.call(
            "Tag 관계 제거",
            status: "204",
            protected: true,
            request_schema: "TagsRelationshipDocument"
          )
        },
        "/api/v1/examples/{id}/tags" => {
          parameters: [ id_parameter ],
          get: operation.call("Tag related resources 조회", "TagCollectionDocument")
        },
        "/api/v1/categories" => {
          get: operation.call("Category 목록 조회", "ExampleCategoryCollectionDocument")
        },
        "/api/v1/categories/{id}" => {
          parameters: [ id_parameter ],
          get: operation.call("Category 조회", "ExampleCategoryDocument")
        },
        "/api/v1/tags" => {
          get: operation.call("Tag 목록 조회", "ExampleTagCollectionDocument")
        },
        "/api/v1/tags/{id}" => {
          parameters: [ id_parameter ],
          get: operation.call("Tag 조회", "ExampleTagDocument")
        },
        "/api/v1/users/me" => {
          get: operation.call("내 프로필 조회", "UserDocument", protected: true)
        },
        "/api/v1/auth/register" => {
          post: operation.call(
            "가입",
            "UserDocument",
            status: "201",
            request_schema: "AuthRegisterDocument"
          )
        },
        "/api/v1/auth/login" => {
          post: operation.call("로그인", "AuthTokenDocument", request_schema: "AuthLoginDocument")
        },
        "/api/v1/auth/refresh" => {
          post: operation.call("Refresh token 회전", "AuthTokenDocument", request_schema: "RefreshTokenDocument")
        },
        "/api/v1/auth/logout" => {
          post: operation.call("로그아웃", status: "204", request_schema: "RefreshTokenDocument")
        }
      },
      components: {
        securitySchemes: {
          BearerAuth: { type: "http", scheme: "bearer" }
        },
        schemas: {
          UserIdentifier: identifier_schema.call("users"),
          UserAttributes: {
            type: "object",
            required: %w[email isActive createdAt updatedAt],
            properties: {
              email: { type: "string", format: "email" },
              isActive: { type: "boolean" },
              createdAt: { type: "string", format: "date-time", readOnly: true },
              updatedAt: { type: "string", format: "date-time", readOnly: true }
            }
          },
          UserResource: {
            allOf: [
              { "$ref" => "#/components/schemas/UserIdentifier" },
              {
                type: "object",
                required: %w[attributes links],
                properties: {
                  attributes: { "$ref" => "#/components/schemas/UserAttributes" },
                  links: { type: "object" }
                }
              }
            ]
          },
          UserDocument: {
            type: "object",
            required: [ "data" ],
            properties: {
              data: { "$ref" => "#/components/schemas/UserResource" }
            }
          },
          AuthCredentialsAttributes: {
            type: "object",
            required: %w[email password],
            properties: {
              email: { type: "string", format: "email", maxLength: 254 },
              password: { type: "string", minLength: 12, maxLength: 128 }
            }
          },
          AuthRegisterDocument: {
            type: "object",
            required: [ "data" ],
            properties: {
              data: {
                type: "object",
                required: %w[type attributes],
                properties: {
                  type: { type: "string", enum: [ "users" ] },
                  attributes: { "$ref" => "#/components/schemas/AuthCredentialsAttributes" }
                }
              }
            }
          },
          AuthLoginDocument: {
            type: "object",
            required: [ "data" ],
            properties: {
              data: {
                type: "object",
                required: %w[type attributes],
                properties: {
                  type: { type: "string", enum: [ "authCredentials" ] },
                  attributes: { "$ref" => "#/components/schemas/AuthCredentialsAttributes" }
                }
              }
            }
          },
          # minLength: 1은 정본 `RawRefreshToken = Annotated[str, Field(min_length=1)]`이
          # OpenAPI로 내보내는 것과 같다(정본 스키마를 직접 덤프해 확인:
          # {"minLength": 1, "type": "string"}). AuthController#refresh_token!이 실제로
          # 강제하므로 문서와 구현이 어긋나지 않는다 — 빈 문자열은 422다.
          RefreshTokenAttributes: {
            type: "object",
            required: [ "refreshToken" ],
            properties: {
              refreshToken: { type: "string", minLength: 1 }
            }
          },
          RefreshTokenDocument: {
            type: "object",
            required: [ "data" ],
            properties: {
              data: {
                type: "object",
                required: %w[type attributes],
                properties: {
                  type: { type: "string", enum: [ "refreshTokens" ] },
                  attributes: { "$ref" => "#/components/schemas/RefreshTokenAttributes" }
                }
              }
            }
          },
          AuthTokenIdentifier: identifier_schema.call("authTokens"),
          AuthTokenAttributes: {
            type: "object",
            required: %w[accessToken refreshToken tokenType expiresIn refreshExpiresIn],
            properties: {
              accessToken: { type: "string" },
              refreshToken: { type: "string" },
              tokenType: { type: "string", enum: [ "Bearer" ] },
              expiresIn: { type: "integer", minimum: 0 },
              refreshExpiresIn: { type: "integer", minimum: 0 }
            }
          },
          AuthTokenResource: {
            # UserResource/ExampleResource와 달리 links를 요구하지 않는다 —
            # AuthTokenSerializer는 self 링크를 내지 않는다(resource_path 없음,
            # app/serializers/auth_token_serializer.rb 참고).
            allOf: [
              { "$ref" => "#/components/schemas/AuthTokenIdentifier" },
              {
                type: "object",
                required: [ "attributes" ],
                properties: {
                  attributes: { "$ref" => "#/components/schemas/AuthTokenAttributes" }
                }
              }
            ]
          },
          AuthTokenDocument: {
            type: "object",
            required: [ "data" ],
            properties: {
              data: { "$ref" => "#/components/schemas/AuthTokenResource" }
            }
          },
          ExampleIdentifier: identifier_schema.call("examples"),
          ExampleCategoryIdentifier: identifier_schema.call("exampleCategories"),
          ExampleTagIdentifier: identifier_schema.call("exampleTags"),
          ExampleAttributes: {
            type: "object",
            required: %w[title description status score createdAt updatedAt],
            properties: {
              title: { type: "string", maxLength: 200 },
              description: { type: "string", nullable: true },
              status: { type: "string", enum: %w[draft active archived] },
              score: { type: "integer", minimum: 0, maximum: 100 },
              createdAt: { type: "string", format: "date-time", readOnly: true },
              updatedAt: { type: "string", format: "date-time", readOnly: true }
            }
          },
          ExampleCreateAttributes: {
            type: "object",
            required: [ "title" ],
            properties: {
              title: { type: "string", maxLength: 200 },
              description: { type: "string", nullable: true },
              status: { type: "string", enum: %w[draft active archived] },
              score: { type: "integer", minimum: 0, maximum: 100 }
            }
          },
          ExamplePatchAttributes: {
            type: "object",
            properties: {
              title: { type: "string", maxLength: 200 },
              description: { type: "string", nullable: true },
              status: { type: "string", enum: %w[draft active archived] },
              score: { type: "integer", minimum: 0, maximum: 100 }
            }
          },
          ExampleReplaceAttributes: {
            type: "object",
            required: [ "title" ],
            properties: {
              title: { type: "string", maxLength: 200 },
              description: { type: "string", nullable: true },
              status: { type: "string", enum: %w[draft active archived] },
              score: { type: "integer", minimum: 0, maximum: 100 }
            }
          },
          ExampleCategoryResource: {
            allOf: [
              { "$ref" => "#/components/schemas/ExampleCategoryIdentifier" },
              {
                type: "object",
                required: %w[attributes links],
                properties: {
                  attributes: {
                    type: "object",
                    required: [ "name" ],
                    properties: { name: { type: "string" } }
                  },
                  links: { type: "object" }
                }
              }
            ]
          },
          ExampleTagResource: {
            allOf: [
              { "$ref" => "#/components/schemas/ExampleTagIdentifier" },
              {
                type: "object",
                required: %w[attributes links],
                properties: {
                  attributes: {
                    type: "object",
                    required: [ "name" ],
                    properties: { name: { type: "string" } }
                  },
                  links: { type: "object" }
                }
              }
            ]
          },
          ExampleRelationships: {
            type: "object",
            required: %w[category tags],
            properties: {
              category: {
                type: "object",
                required: %w[data links],
                properties: {
                  data: {
                    allOf: [ { "$ref" => "#/components/schemas/ExampleCategoryIdentifier" } ],
                    nullable: true
                  },
                  links: { type: "object" }
                }
              },
              tags: {
                type: "object",
                required: %w[data links],
                properties: {
                  data: {
                    type: "array",
                    items: { "$ref" => "#/components/schemas/ExampleTagIdentifier" }
                  },
                  links: { type: "object" }
                }
              }
            }
          },
          ExampleWriteRelationships: {
            type: "object",
            properties: {
              category: {
                type: "object",
                required: [ "data" ],
                properties: {
                  data: {
                    allOf: [ { "$ref" => "#/components/schemas/ExampleCategoryIdentifier" } ],
                    nullable: true
                  }
                }
              },
              tags: {
                type: "object",
                required: [ "data" ],
                properties: {
                  data: {
                    type: "array",
                    items: { "$ref" => "#/components/schemas/ExampleTagIdentifier" }
                  }
                }
              }
            }
          },
          ExampleResource: {
            allOf: [
              { "$ref" => "#/components/schemas/ExampleIdentifier" },
              {
                type: "object",
                required: %w[attributes relationships links],
                properties: {
                  attributes: { "$ref" => "#/components/schemas/ExampleAttributes" },
                  relationships: { "$ref" => "#/components/schemas/ExampleRelationships" },
                  links: { type: "object" }
                }
              }
            ]
          },
          ExampleCreateDocument: {
            type: "object",
            required: [ "data" ],
            properties: {
              data: {
                type: "object",
                required: %w[type attributes],
                properties: {
                  type: { type: "string", enum: [ "examples" ] },
                  attributes: { "$ref" => "#/components/schemas/ExampleCreateAttributes" },
                  relationships: { "$ref" => "#/components/schemas/ExampleWriteRelationships" }
                }
              }
            }
          },
          ExamplePatchDocument: {
            type: "object",
            required: [ "data" ],
            properties: {
              data: {
                type: "object",
                required: %w[type id],
                anyOf: [
                  { required: [ "attributes" ] },
                  { required: [ "relationships" ] }
                ],
                properties: {
                  type: { type: "string", enum: [ "examples" ] },
                  id: { type: "string", format: "uuid" },
                  attributes: { "$ref" => "#/components/schemas/ExamplePatchAttributes" },
                  relationships: { "$ref" => "#/components/schemas/ExampleWriteRelationships" }
                }
              }
            }
          },
          ExampleReplaceDocument: {
            type: "object",
            required: [ "data" ],
            properties: {
              data: {
                type: "object",
                required: %w[type id attributes],
                properties: {
                  type: { type: "string", enum: [ "examples" ] },
                  id: { type: "string", format: "uuid" },
                  attributes: { "$ref" => "#/components/schemas/ExampleReplaceAttributes" },
                  relationships: { "$ref" => "#/components/schemas/ExampleWriteRelationships" }
                }
              }
            }
          },
          ExampleDocument: {
            type: "object",
            required: [ "data" ],
            properties: {
              data: { "$ref" => "#/components/schemas/ExampleResource" },
              included: {
                type: "array",
                items: {
                  oneOf: [
                    { "$ref" => "#/components/schemas/ExampleCategoryResource" },
                    { "$ref" => "#/components/schemas/ExampleTagResource" }
                  ]
                }
              }
            }
          },
          ExampleCollectionDocument: {
            type: "object",
            required: %w[data links],
            properties: {
              data: {
                type: "array",
                items: { "$ref" => "#/components/schemas/ExampleResource" }
              },
              included: {
                type: "array",
                items: {
                  oneOf: [
                    { "$ref" => "#/components/schemas/ExampleCategoryResource" },
                    { "$ref" => "#/components/schemas/ExampleTagResource" }
                  ]
                }
              },
              meta: {
                type: "object",
                required: [ "totalCount" ],
                properties: { totalCount: { type: "integer", minimum: 0 } }
              },
              links: { type: "object" }
            }
          },
          CategoryRelationshipDocument: {
            type: "object",
            required: [ "data" ],
            properties: {
              data: {
                allOf: [ { "$ref" => "#/components/schemas/ExampleCategoryIdentifier" } ],
                nullable: true
              },
              links: { type: "object" }
            }
          },
          TagsRelationshipDocument: {
            type: "object",
            required: [ "data" ],
            properties: {
              data: {
                type: "array",
                items: { "$ref" => "#/components/schemas/ExampleTagIdentifier" }
              },
              links: { type: "object" }
            }
          },
          CategoryDocument: {
            type: "object",
            required: [ "data" ],
            properties: {
              data: {
                allOf: [ { "$ref" => "#/components/schemas/ExampleCategoryResource" } ],
                nullable: true
              }
            }
          },
          TagCollectionDocument: {
            type: "object",
            required: %w[data links],
            properties: {
              data: {
                type: "array",
                items: { "$ref" => "#/components/schemas/ExampleTagResource" }
              },
              meta: {
                type: "object",
                required: [ "totalCount" ],
                properties: { totalCount: { type: "integer", minimum: 0 } }
              },
              links: { type: "object" }
            }
          },
          ExampleCategoryDocument: {
            type: "object",
            required: [ "data" ],
            properties: {
              data: { "$ref" => "#/components/schemas/ExampleCategoryResource" }
            }
          },
          ExampleCategoryCollectionDocument: {
            type: "object",
            required: %w[data links],
            properties: {
              data: {
                type: "array",
                items: { "$ref" => "#/components/schemas/ExampleCategoryResource" }
              },
              meta: {
                type: "object",
                required: [ "totalCount" ],
                properties: { totalCount: { type: "integer", minimum: 0 } }
              },
              links: { type: "object" }
            }
          },
          ExampleTagDocument: {
            type: "object",
            required: [ "data" ],
            properties: {
              data: { "$ref" => "#/components/schemas/ExampleTagResource" }
            }
          },
          ExampleTagCollectionDocument: {
            type: "object",
            required: %w[data links],
            properties: {
              data: {
                type: "array",
                items: { "$ref" => "#/components/schemas/ExampleTagResource" }
              },
              meta: {
                type: "object",
                required: [ "totalCount" ],
                properties: { totalCount: { type: "integer", minimum: 0 } }
              },
              links: { type: "object" }
            }
          }
        }
      }
    }
  }

  config.openapi_format = :yaml
end
