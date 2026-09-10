<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# public

## Purpose

Static browser-facing files: Rails fallback error pages, red-square icon placeholders, and a robots file. These HTML pages are separate from JSON:API error documents returned by controllers.

## Key Files

| File | Description |
|------|-------------|
| `404.html` | Missing-page fallback. |
| `406-unsupported-browser.html` | Unsupported-browser fallback. |
| `422.html` | Rejected-change fallback. |
| `500.html` | Generic server-error fallback. |
| `icon.png` | 512-by-512 red-square raster icon. |
| `icon.svg` | 100-by-100 red-square vector icon. |
| `robots.txt` | Comment-only file; contains no crawler directives. |

## For AI Agents

### Working In This Directory

- Keep fallback pages self-contained; each uses inline CSS and a viewport meta tag.
- Do not use static HTML pages to define API error status/code/translation behavior. That contract belongs to controller concerns, `JsonApiError`, locales, and request specs.
- Generated `public/assets` output is ignored; asset sources belong under `app/assets/`.

### Testing Requirements

Open edited HTML/icons in a browser and inspect narrow and wide layouts. For changes to serving behavior, use the relevant environment/controller tests. There is no static-page-specific test suite in this directory.

### Common Patterns

The four error pages share the `rails-default-error-page` class and dialog styles. Icons are intentionally plain placeholders.

## Dependencies

### Internal

Rails static-file configuration and the asset build in `Dockerfile`.

### External

Browser HTML/CSS/SVG/PNG rendering; no JavaScript or external stylesheet is loaded by these pages.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
