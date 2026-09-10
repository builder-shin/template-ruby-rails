<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# assets

## Purpose

Sprockets source assets for the scaffold application layout. The manifest links images and CSS; no JavaScript application entry point is present here.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| [config/](config/AGENTS.md) | Sprockets asset manifest. |
| [images/](images/AGENTS.md) | Tracked image-directory placeholder. |
| [stylesheets/](stylesheets/AGENTS.md) | Application stylesheet manifest. |

## For AI Agents

### Working In This Directory

Keep new source assets reachable through config/manifest.js and stylesheet directives. The layout requests the application stylesheet; the API controllers do not render this layout.

### Testing Requirements

For asset changes, validate the asset-precompilation stage using the documented Docker build and inspect affected rendered pages if a route renders them. No dedicated asset specs are present in the current spec/test inventory.

## Dependencies

config/initializers/assets.rb sets the asset version. app/views/layouts/application.html.erb includes application.css. Sprockets integration comes from sprockets-rails in Gemfile.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
