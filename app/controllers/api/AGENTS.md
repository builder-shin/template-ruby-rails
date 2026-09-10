<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# api

## Purpose

Namespace container for the versioned API controllers selected by config/routes.rb.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| [v1/](v1/AGENTS.md) | Example/reference resources, auth endpoints, and the current user's profile. |

## For AI Agents

Keep controller module names aligned with the Api::V1 namespace and route declarations. New versions should have an explicit route/contract boundary. The ApiController base lives one level above this directory and supplies generic resource behavior only to subclasses that choose it.

## Testing Requirements

Run affected spec/requests/api/v1 and spec/routing/api/v1 examples. Public API changes also require the generated Swagger validation described in the root guide.

## Dependencies

ApplicationController/ApiController, shared controller concerns, models/serializers, and config/routes.rb.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
