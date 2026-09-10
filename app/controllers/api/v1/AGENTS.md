<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# v1

## Purpose

Version-one JSON:API endpoints for Example CRUD/relationships, public reference resources, local authentication, and the authenticated user's profile.

## Key Files

| File | Description |
|------|-------------|
| [examples_controller.rb](examples_controller.rb) | Example query/relationship policy, canonical UUID handling, and active-user guards on all write actions. |
| [example_categories_controller.rb](example_categories_controller.rb) | Public category index/show policy with name filtering, name/createdAt sorting, and no includes/relationships. |
| [example_tags_controller.rb](example_tags_controller.rb) | Public tag index/show policy matching category behavior. |
| [auth_controller.rb](auth_controller.rb) | Registration, login, refresh rotation, logout, auth document validation, email normalization, and post-commit error conversion. |
| [users_controller.rb](users_controller.rb) | Authenticated /users/me profile lookup using Current.user, including inactive users. |

## For AI Agents

### Working In This Directory

- config/routes.rb is the public action boundary. Categories and tags inherit generic write methods but have only index/show routes and no auth callback; adding a write route would expose an unauthenticated mutation.
- Example reads are public. Keep create/update/upsert/destroy and all relationship mutation actions in PROTECTED_WRITE_ACTIONS. PATCH updates and PUT replaces/upserts through different shared actions.
- Example query policy allows title/status/score/category.id/createdAt filters, selected sort fields, category/tags includes, createdAt descending default order, and ascending ID tie-breaker. Reference resources default to name ascending with the same ID tie-breaker.
- Reference resource types remain exampleCategories/exampleTags while paths are /categories and /tags. Their show mode is include_only even with no allowed relationships so invalid query families retain the correct errors.
- AuthController and UsersController inherit ApplicationController directly. Auth actions handle different request/response types and cannot use CrudActions' inferred single model.
- Preserve registration's database-index-specific EMAIL_ALREADY_REGISTERED mapping and common email strip/full-Unicode-fold normalization at both registration and login. Validate email length before and after normalization; passwords are strings of 12..128 characters.
- Login verifies either the real or dummy password hash before revealing inactive status, then locks the user and issues tokens. Refresh/logout commit session-service Failure results before raising their JSON:API errors.
- /users/me uses authenticate_user!, which intentionally permits inactive accounts to inspect their profile; active-user enforcement belongs to protected Example writes.

### Testing Requirements

Run affected spec/requests/api/v1 cases and spec/routing/api/v1. Auth request specs check registration/login documents and response fields; reference-resource specs verify names/types/links; query specs exercise declared policy. Use the root Swagger regeneration and full-suite checks when changing the public contract.

### Common Patterns

Resource controllers override policy methods rather than duplicating query/CRUD code. UUIDs normalize to lowercase before lookup. Auth writes explicitly render JSONAPI media type and ActiveSupport-converted JSON; user reads use render jsonapi:.

## Dependencies

### Internal

ApplicationController/ApiController, controller concerns, Example/User/reference models, serializers, Auth services, Current, and config/routes.rb.

### External

Rails/Active Record, PostgreSQL diagnostics for the users-email index, jsonapi.rb, jsonapi-serializer, Argon2, and JWT through Auth services.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
