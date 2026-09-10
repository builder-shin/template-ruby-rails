<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# concerns

## Purpose

Shared controller behavior for JSON:API resource operations, wire-format validation, authentication, query processing, and relationships. These are top-level concern constants, not a Concerns namespace.

## Key Files

| File | Description |
|------|-------------|
| [crud_actions.rb](crud_actions.rb) | Generic CRUD/upsert, write-document validation, serialization hooks, legacy filtering, and contract-driven collection rendering. |
| [jsonapi_authentication.rb](jsonapi_authentication.rb) | Bearer access-token authentication and optional active-user enforcement through Current.user. |
| [jsonapi_errors.rb](jsonapi_errors.rb) | Exception mapping, safe localized error documents, Accept-Language selection, and Vary handling. |
| [jsonapi_negotiation.rb](jsonapi_negotiation.rb) | Accept/Content-Type parsing, top-level JSON:API validation, and response media-type normalization. |
| [jsonapi_query.rb](jsonapi_query.rb) | Rails callback integration, raw-query shape-conflict handling, and per-action query rules. |
| [jsonapi_relationships.rb](jsonapi_relationships.rb) | Example category/tag linkage reads/writes, related-resource pagination, identifier validation, and locked mutations. |
| [.keep](.keep) | Original empty directory placeholder retained alongside implemented concerns. |

## For AI Agents

### Working In This Directory

- CrudActions derives its model from controller_name unless overridden. Keep resource/type/allowed-attribute/query/relationship declarations in concrete controllers; auth flows do not satisfy the single-model assumption.
- Preserve PATCH partial-update behavior and PUT upsert replacement behavior. Upsert resets omitted writable attributes/relationships and obtains a transaction-scoped PostgreSQL advisory lock for the normalized ID.
- Write serialization uses payload.as_json before JSON.generate to match read-path timestamp encoding. Successful JSON:API documents and errors must retain application/vnd.api+json without charset parameters; bodyless responses keep their existing semantics.
- Authentication's 401 errors include source.header = Authorization. Inactive-user rejection is a separate 403 without that source. authenticate_user! permits inactive users; authenticate_active_user! adds the active check.
- Query parsing/SQL belongs in app/lib/jsonapi. Preserve raw duplicate/shape checks before Rails loses conflicting parameter shapes, and keep action-specific family error codes.
- Relationship writes validate linkage, lock the parent row, and execute atomically. Tag additions use insert_all for duplicate-safe join inserts; related tag reads order by ID and accept only page[number]/page[size], always returning totalCount.
- Extend JsonApiError's allowlist and translations together. Unexpected exceptions are logged server-side and rendered as safe internal errors, never exposed directly.

### Testing Requirements

Run relevant spec/requests/api/v1 cases covering CRUD/upsert, query/action-query, relationships/concurrency, auth, errors, negotiation, and exact response Content-Type. Shared changes can affect all resource controllers, including public reference endpoints. Finish with root full-suite/static checks for runtime changes.

### Common Patterns

ActiveSupport::Concern assembles callbacks and reusable methods. Concrete controller policies restrict exposed fields and relationships. Error locations distinguish JSON pointers, query parameters, and HTTP headers; localized errors default to Korean when no supported preference wins.

## Dependencies

### Internal

app/lib/auth and app/lib/jsonapi, JsonApiError, Current/User, resource models/serializers, and config/locales JSON:API translations.

### External

ActionController/Active Record, jsonapi.rb, jsonapi-serializer, Ransack's legacy query path, I18n, PostgreSQL, and Ruby JSON/URI libraries.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
