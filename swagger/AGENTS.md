<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# swagger

## Purpose

Committed generated OpenAPI documents served by rswag under `/api-docs`. The source specification is assembled in `spec/swagger_helper.rb`; the generated artifact is also included in the production image.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| [v1/](v1/AGENTS.md) | Version 1 JSON:API schemas, operations, and authentication declarations. |

## For AI Agents

### Working In This Directory

- Update the source definitions in `spec/swagger_helper.rb` and regenerate the document for API changes.
- Keep the generated YAML tracked and aligned with routes and runtime authentication requirements.
- The rswag API root is configured in `config/initializers/rswag_api.rb`; the UI endpoint is configured in `config/initializers/rswag_ui.rb`.

### Testing Requirements

- With the root test environment configured and `COVERAGE_MINIMUM=0`, run `bundle exec rails rswag:specs:swaggerize`.
- Run the Swagger contract/security specs in `spec/configuration/` and `spec/requests/api_docs_spec.rb` after generation. The security spec intentionally lives outside the request-generation glob so it reads the completed artifact.
- Review the resulting diff. CI verifies freshness with `git diff --exit-code -- swagger/v1/swagger.yaml`.

### Common Patterns

The current document uses OpenAPI 3.0.1, JSON:API media types, reusable component schemas, and per-operation Bearer authentication.

## Dependencies

### Internal

`spec/swagger_helper.rb` defines the document; configuration specs compare it with the generated YAML and live route behavior; routes and rswag initializers serve it.

### External

rswag-specs for generation; rswag-api and rswag-ui for serving; YAML and OpenAPI tooling.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
