<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# controllers

## Purpose

HTTP entry points built on ActionController::API. ApplicationController supplies JSON:API negotiation/errors; ApiController adds resource CRUD machinery; health checks bypass JSON:API request negotiation.

## Key Files

| File | Description |
|------|-------------|
| [application_controller.rb](application_controller.rb) | Includes error/negotiation concerns and renders unmatched API routes through RESOURCE_NOT_FOUND. |
| [api_controller.rb](api_controller.rb) | Adds CrudActions to the application base. |
| [health_controller.rb](health_controller.rb) | Liveness returns 200 without a database query; readiness executes SELECT 1 and maps database failures to 503. |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| [api/](api/AGENTS.md) | Versioned resource/auth endpoints. |
| [concerns/](concerns/AGENTS.md) | CRUD, authentication, errors, negotiation, queries, and relationships. |

## For AI Agents

### Working In This Directory

- Use ApiController when the endpoint maps to a resource model through CrudActions. AuthController and UsersController inherit ApplicationController because their flows do not need generic CRUD.
- Preserve HealthController's skipped negotiation and distinguish database readiness failures from programming errors, which still use the global safe error handler.
- Verify config/routes.rb when adding actions: method inheritance alone does not define public endpoints.

### Testing Requirements

Run affected request/routing specs. Health behavior is covered in spec/requests/health_spec.rb; shared API changes need the relevant spec/requests/api/v1 coverage and root final checks.

### Common Patterns

Request protocol behavior lives in concerns; versioned controllers select policy and delegate persistence/serialization. Rendering a write response must preserve application/vnd.api+json without charset parameters.

## Dependencies

### Internal

app/errors/json_api_error.rb (JsonApiError), app/models, app/serializers, app/lib, and config/routes.rb.

### External

ActionController, Active Record, PostgreSQL's pg adapter, jsonapi.rb, and jsonapi-serializer.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
