<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# stylesheets

## Purpose

Application stylesheet entry point for the scaffold HTML layout.

## Key Files

| File | Description |
|------|-------------|
| [application.css](application.css) | Sprockets CSS manifest with require_tree and require_self; no custom styles are defined yet. |

## For AI Agents

Preserve manifest directives and put application-wide overrides after them as the source comment specifies. Scoped CSS can be added in separate files picked up by require_tree. Validate compilation and visually inspect a page that actually renders the application layout; API JSON responses do not use these styles.

## Dependencies

The sibling config/manifest.js links CSS, and app/views/layouts/application.html.erb requests the application stylesheet. Processing uses sprockets-rails.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
