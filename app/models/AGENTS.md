<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# models

## Purpose

Active Record models for the Example sample domain and local authentication, plus request-local Current attributes.

## Key Files

| File | Description |
|------|-------------|
| [application_record.rb](application_record.rb) | Abstract model base; exposes model columns/associations to Ransack while controllers define query policy. |
| [current.rb](current.rb) | ActiveSupport::CurrentAttributes for user and request_id. |
| [example.rb](example.rb) | Validated title/score/status resource with optional category and tags ordered by ID. |
| [example_category.rb](example_category.rb) | Named unique category referenced by examples through category_id. |
| [example_tag.rb](example_tag.rb) | Named unique tag with join records and related examples. |
| [example_tagging.rb](example_tagging.rb) | Composite example_id/tag_id join model with scoped tag uniqueness. |
| [user.rb](user.rb) | Email/password-hash presence validation and dependent refresh sessions; email uniqueness is enforced by the database. |
| [refresh_session.rb](refresh_session.rb) | User session with required token hash/expiry and optional replacement-session association; token-hash uniqueness is enforced by the database. |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| [concerns/](concerns/AGENTS.md) | Empty tracked model-concern placeholder. |

## For AI Agents

### Working In This Directory

- Keep User email normalization in the registration/login flow, where storage and lookup share it. Do not introduce an email uniqueness validator: the database conflict is translated to 409 EMAIL_ALREADY_REGISTERED by AuthController.
- Keep RefreshSession token-hash uniqueness at the database layer; a model validator adds a query on every issuance/rotation and changes conflict/error behavior.
- Example status uses a string enum with validate: true so invalid values produce validation errors instead of assignment exceptions. Tags have a stable order(:id) association.
- Coordinate relation and key changes with controllers, serializers, database migrations, and relationship/concurrency specs. ApplicationRecord's broad Ransack hooks are not the public filter allowlist.

### Testing Requirements

Run spec/models plus affected API/auth/relationship specs. User specs explicitly exercise database uniqueness even when model validation is bypassed. Follow the root PostgreSQL setup and full-suite coverage gate.

### Common Patterns

Domain classes inherit ApplicationRecord; Current inherits ActiveSupport::CurrentAttributes instead. Join records use a composite primary key, and authentication models deliberately avoid application-level uniqueness prequeries.

## Dependencies

### Internal

Auth services/controllers manage user/session transitions; serializers define exposed model attributes. Database migrations/schema define persisted constraints.

### External

Active Record, ActiveSupport, PostgreSQL, and Ransack.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
