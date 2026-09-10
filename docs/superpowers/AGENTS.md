<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# superpowers

## Purpose

Design and implementation records for the Example API migration and later cross-template contract alignment.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| [specs/](specs/AGENTS.md) | July Example-domain design and September contract-parity design. |
| [plans/](plans/AGENTS.md) | Detailed Example migration, JSON:API layer, and local JWT authentication plans. |

## For AI Agents

Treat dates and plan scopes as part of the context. The July design preserves external session authentication; September's C1/C2 work introduces reference-resource reads, revised pagination, and local JWT authentication. Read the relevant design and plan together, then check current routes and specs before reusing sample code or commands.

When editing these records, preserve the distinction between the historical starting state, intended change, and verified current behavior. Validate local links; sibling repositories named in the documents are external context and are not included in this checkout.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
