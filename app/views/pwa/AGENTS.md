<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# pwa

## Purpose

Unused PWA scaffold templates. The current route file has no manifest or service-worker endpoints.

## Key Files

| File | Description |
|------|-------------|
| [manifest.json.erb](manifest.json.erb) | Template manifest with Template branding, /icon.png icons, standalone display, root scope/start URL, and red colors. |
| [service-worker.js](service-worker.js) | Commented push-notification and notification-click handler examples; no active worker behavior. |

## For AI Agents

Treat these files as scaffolding until routing and registration are implemented. If activating the PWA, coordinate manifest branding/icons, start URL, serving routes, browser registration, and the application layout's manifest link. Uncommenting worker examples alone does not establish a functioning feature.

## Testing Requirements

No PWA-specific tests exist in the current inventory. Validate rendered manifest JSON and actual browser registration/notification behavior when introducing active PWA support.

## Dependencies

Rails template serving, the application layout, static /icon.png, and browser Service Worker/Notification APIs if the examples are activated.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
