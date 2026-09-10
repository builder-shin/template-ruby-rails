<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# serializers

## Purpose

JSON:API resource definitions specifying public attributes, resource types, canonical IDs, links, and Example relationships.

## Key Files

| File | Description |
|------|-------------|
| [application_serializer.rb](application_serializer.rb) | Includes JSONAPI::Serializer for concrete serializers. |
| [example_serializer.rb](example_serializer.rb) | Example attributes and category/tag linkage with normalized IDs and self/related URLs. |
| [example_category_serializer.rb](example_category_serializer.rb) | exampleCategories resource with name and /api/v1/categories/:id self link. |
| [example_tag_serializer.rb](example_tag_serializer.rb) | exampleTags resource with name and /api/v1/tags/:id self link. |
| [user_serializer.rb](user_serializer.rb) | Public profile fields and fixed /api/v1/users/me self link. |
| [auth_token_serializer.rb](auth_token_serializer.rb) | Access/refresh TokenPair fields; intentionally declares no resource links. |

## For AI Agents

### Working In This Directory

- Concrete serializers use camel_lower key transformation and lowercase string IDs. Preserve normalization for primary resources, relationship linkage, and URL components.
- Resource types and route names can differ: exampleCategories uses /categories and exampleTags uses /tags. Confirm links against config/routes.rb.
- UserSerializer must keep its fixed /users/me link and omit password_hash. AuthTokenSerializer has no self URL because issued token-pair resources cannot be fetched separately; omitting links differs from emitting an empty links object.
- ExampleSerializer wraps related records in NormalizedRelationship values; test identifiers supplied in uppercase without relying on PostgreSQL to normalize them.

### Testing Requirements

Run spec/serializers/example_serializer_spec.rb and affected API request specs, including auth and reference resources. These exercise primary IDs, linkage, included resources, canonical URLs, and the wire document. API contract changes also require the root Swagger regeneration checks.

## Dependencies

### Internal

app/models resource objects, Auth::RefreshSessions::TokenPair, and route shapes in config/routes.rb. Controller rendering controls response headers and timestamp conversion.

### External

jsonapi-serializer and Rails/ActiveSupport JSON serialization.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
