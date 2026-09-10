<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# v1

## Purpose

Generated OpenAPI 3.0.1 contract for the version 1 Example and authentication API, with the local server at `http://localhost:4000`.

## Key Files

| File | Description |
|------|-------------|
| `swagger.yaml` | Operations, per-operation Bearer security, JSON:API request/response documents, resource identifiers, attributes, and relationships. |

## For AI Agents

### Working In This Directory

- Edit `spec/swagger_helper.rb` and regenerate this file. Keep the generated output aligned with the source specification, routes, serializers, and runtime authorization.
- Preserve separate create, patch, and replacement schemas: creation/replacement requires a title; PATCH requires an ID and at least attributes or relationships. PUT documents both 200 and 201 responses.
- Resource documents and relationship linkage have different shapes. Category linkage is nullable; tags linkage is an array of identifiers. Collections expose links and optional total-count metadata.
- Example writes/relationship mutations and `/api/v1/users/me` declare `BearerAuth`; public reads and register/login/refresh/logout omit operation security.
- Auth request resource types differ: `users`, `authCredentials`, and `refreshTokens`. `authTokens` responses contain token attributes and deliberately do not require resource links.
- Keep public attribute names camelCase and request/response media types `application/vnd.api+json`.

### Testing Requirements

- Regenerate using `bundle exec rails rswag:specs:swaggerize` with the root test environment and `COVERAGE_MINIMUM=0`.
- Run `bundle exec rspec spec/configuration/swagger_contract_spec.rb spec/configuration/swagger_security_contract_spec.rb spec/requests/api_docs_spec.rb` after generation.
- The contract spec checks source/output equality; the security spec independently probes routes without Authorization and compares runtime 401 behavior with generated security declarations.

### Common Patterns

Reusable component schemas use `$ref` and `allOf`. UUID identifiers distinguish resources from their attributes, and success responses that return no document use HTTP 204.

## Dependencies

### Internal

`spec/swagger_helper.rb`, `config/routes.rb`, rswag initializers, serializers, request contracts, and the route-probing support used by the security contract spec.

### External

OpenAPI 3.0.1, YAML, rswag, and RSpec.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
