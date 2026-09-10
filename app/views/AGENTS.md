<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# views

## Purpose

Rails HTML/email layout and PWA scaffold templates retained in the API-only application. Current routes do not expose the PWA manifest/service worker or a root HTML page.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| [layouts/](layouts/AGENTS.md) | Application document shell and HTML/plain-text mail layouts. |
| [pwa/](pwa/AGENTS.md) | Manifest template and commented service-worker examples. |

## For AI Agents

Check routes and controller inheritance before assuming a template is reachable. Add rendering routes/controllers and appropriate tests together if introducing a browser feature. Mail layouts are selected by ApplicationMailer; JSON:API controllers serialize resources directly.

## Testing Requirements

No dedicated view specs are present. Render and inspect affected output when introducing reachable templates; retain root API request checks when controller behavior changes.

## Dependencies

Rails ERB/Action View, app/assets/stylesheets/application.css, ApplicationMailer, and static icon paths referenced by templates.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
