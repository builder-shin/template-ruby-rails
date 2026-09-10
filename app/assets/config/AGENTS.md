<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# config

## Purpose

Declares the asset sources Sprockets links into compiled output.

## Key Files

| File | Description |
|------|-------------|
| [manifest.js](manifest.js) | Links the images tree and CSS files directly in the sibling stylesheets directory. |

## For AI Agents

Treat manifest.js as Sprockets directives, not executable browser JavaScript. Keep paths relative to this directory and include new asset types explicitly when necessary. Validate changes through the documented asset-precompilation Docker build; no dedicated manifest tests are present.

## Dependencies

Sibling images/ and stylesheets/ directories, sprockets-rails, and config/initializers/assets.rb.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
