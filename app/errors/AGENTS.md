<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# errors

## Purpose

Defines the validated error object passed from controllers/services to the shared JSON:API renderer.

## Key Files

| File | Description |
|------|-------------|
| [json_api_error.rb](json_api_error.rb) | JsonApiError validates HTTP error status and an allowlist of codes, normalizes source/context, and freezes exposed metadata. |

## For AI Agents

### Working In This Directory

Keep the status range 400..599 and error-code allowlist deliberate. Preserve source.pointer, source.parameter, and source.header; authentication errors rely on Authorization surviving normalization. Coordinate new codes with JsonapiErrors and both JSON:API locale files so untranslated errors do not fall back to INTERNAL_SERVER_ERROR.

### Testing Requirements

Run spec/errors/json_api_error_spec.rb and affected API error/auth request specs. The error unit spec checks source filtering/freezing and rejected statuses/codes.

## Dependencies

ActiveSupport hash normalization helpers; app/controllers/concerns/jsonapi_errors.rb renders this object and resolves I18n translations.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
