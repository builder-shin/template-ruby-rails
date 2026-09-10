<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# app

## Purpose

Runtime source for the Rails JSON:API application: Example resources and relationships, local JWT authentication, reusable request/query behavior, persistence, serialization, and background processing. Rails presentation and Action Cable scaffolding remains alongside the API implementation.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| [assets/](assets/AGENTS.md) | Sprockets manifests, application stylesheet, and image placeholder. |
| [channels/](channels/AGENTS.md) | Empty Action Cable channel and connection base classes. |
| [controllers/](controllers/AGENTS.md) | Health endpoints, API v1 controllers, and shared JSON:API concerns. |
| [errors/](errors/AGENTS.md) | Validated JSON:API error value. |
| [helpers/](helpers/AGENTS.md) | Empty application view-helper module. |
| [jobs/](jobs/AGENTS.md) | Image variants and expired refresh-session cleanup. |
| [lib/](lib/AGENTS.md) | Auth primitives/services and JSON:API query machinery. |
| [mailers/](mailers/AGENTS.md) | Base mailer and default mail layout selection. |
| [models/](models/AGENTS.md) | Example/category/tag, user, refresh-session, and request-local models. |
| [serializers/](serializers/AGENTS.md) | JSON:API resources, relationships, public attributes, and canonical links. |
| [views/](views/AGENTS.md) | HTML/email layouts and PWA scaffold templates. |

## For AI Agents

### Working In This Directory

- Trace an API change through routes, controller policy, shared concerns/services, model constraints, serializer, and request specs. Inherited controller actions are exposed only when routes declare them.
- Preserve camelCase JSON:API attributes, lowercase resource IDs, exact media types, and error source locations. Rails names remain snake_case internally.
- Authentication services return failure values when security changes must commit; controllers raise the corresponding API error after leaving the transaction.
- The application is configured API-only. Existing view, mailer, and Cable scaffolds do not establish a working browser UI or authenticated websocket flow.

### Testing Requirements

Run relevant RSpec directories from the repository root, then the full suite and applicable static checks according to the root guide. Request contracts are under spec/requests/api/v1; domain, serializer, library, and job specs cover the corresponding layers. AGENTS-only edits require documentation validation, not application execution.

### Common Patterns

Controllers declare query/relationship policy; concerns handle protocol behavior; app/lib contains reusable logic. ApplicationRecord and ApplicationSerializer provide common bases, while Current stores request-local user and request_id values.

## Dependencies

### Internal

config/routes.rb selects reachable actions; config/application.rb selects API mode, locale, and the Sidekiq adapter. Tests live in spec/ and scaffold tests in test/.

### External

Rails/Active Record, PostgreSQL, jsonapi.rb, jsonapi-serializer, JWT, Argon2, Sidekiq, and Active Storage, as declared in Gemfile.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
