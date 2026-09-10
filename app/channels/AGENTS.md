<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# channels

## Purpose

Action Cable namespace scaffold. Only base channel and connection classes exist; there are no feature subscriptions or connection authentication rules.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| [application_cable/](application_cable/AGENTS.md) | ApplicationCable base classes. |

## For AI Agents

### Working In This Directory

Read the base connection before adding channels: it currently declares no authenticated identity. API Bearer guards in controller concerns are not automatically applied to websocket connections.

### Testing Requirements

The connection test under test/channels/application_cable is only a commented scaffold. Add meaningful connection/subscription tests when implementing websocket behavior; follow the root test setup.

## Dependencies

Action Cable is declared in Gemfile. config/cable.yml selects async in development, test in test, and Redis in production.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
