<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# specs

## Purpose

Design records specifying API behavior, architecture, migration scope, and validation expectations for the Example template and later contract parity.

## Key Files

| File | Description |
|------|-------------|
| `2026-07-15-example-api-parity-design.md` | Example-domain replacement design: CRUD/upsert, relationships, JSON:API negotiation/errors, external auth, and Compose. |
| `2026-09-04-contract-parity-design.md` | Later design for resource-declared query policies, probe/cursor pagination, local JWT auth, and public category/tag reads. |

## For AI Agents

### Working In This Directory

- Read dates and scope before interpreting statements as current. The September design supersedes July's external-auth and relationship-only reference-resource assumptions.
- Cross-check design paths and mechanisms with implementation: current auth helpers are under `app/lib/auth/`; reference resources are made read-only by `config/routes.rb`, not a special route-registering option in `CrudActions`.
- The September design's initial comparison table records the state before implementation. Its references to sibling FastAPI, NestJS, and Next.js repositories are design context, not files present here.
- Preserve Korean explanations, contract tables, and links to corresponding plans. Do not copy old snippets over current code without checking their associated tests.

### Testing Requirements

For prose changes, verify local paths and consistency with affected plans. Contract changes require corresponding request/configuration specs and Swagger regeneration as described in the root guide.

### Common Patterns

Dated design documents describe goals, non-goals, API contracts, ordered implementation phases, testing, and risks.

## Dependencies

### Internal

`../plans/`, `../../../config/routes.rb`, `../../../app/`, `../../../spec/`, and `../../../swagger/v1/swagger.yaml`.

### External

Contract references to sibling FastAPI/NestJS/Next.js template projects; these are not vendored in this repository.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
