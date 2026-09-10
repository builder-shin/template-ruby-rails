<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# locales

## Purpose

Rails I18n catalogs, primarily the English and Korean text for the application's 24 approved JSON:API error codes. Error rendering chooses supported languages from `Accept-Language` and otherwise uses Korean.

## Key Files

| File | Description |
|------|-------------|
| `jsonapi.en.yml` | English `title` and `detail` text for each JSON:API error code. |
| `jsonapi.ko.yml` | Matching Korean catalog, including negotiation, validation, resource, and authentication errors. |
| `en.yml` | Rails starter translation guidance and the `hello` example. |

## For AI Agents

### Working In This Directory

- Keep the two JSON:API catalogs aligned with `JsonApiError::ERROR_CODES` in `app/errors/json_api_error.rb` and the expected-code list in the request specs.
- Every approved code needs nonblank `title` and `detail` values in both catalogs. Missing translated text causes the error-rendering concern to fall back to a safe 500 response.
- Preserve UTF-8 Korean text and YAML structure. Quote strings that YAML might interpret as booleans.
- Keep error text suitable for clients; internal exception details are handled separately by the error-rendering concern.

### Testing Requirements

Run `bundle exec rspec spec/requests/api/v1/jsonapi_errors_spec.rb` for catalog changes. It checks both catalogs, Korean defaults, English negotiation, and safe behavior when translations are missing. Run `spec/errors/json_api_error_spec.rb` when changing the approved code registry.

### Common Patterns

Catalog keys are `<locale>.jsonapi.errors.<UPPERCASE_CODE>.title/detail`. Stable error codes remain language-independent; translated titles/details are selected at rendering time.

## Dependencies

### Internal

`app/errors/json_api_error.rb`, `app/controllers/concerns/jsonapi_errors.rb`, `config/application.rb`, and the JSON:API error request specs.

### External

Rails I18n, rails-i18n, and YAML parsing.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
