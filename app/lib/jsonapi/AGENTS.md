<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# jsonapi

## Purpose

Reusable query engine translating controller-declared filters, sorts, includes, and pagination into Active Record scopes and JSON:API links. This namespace is Jsonapi; JSONAPI refers to the external gem integration.

## Key Files

| File | Description |
|------|-------------|
| [raw_query.rb](raw_query.rb) | UTF-8 query-pair decoding and scalar/hash/array shape-conflict detection with family-specific errors. |
| [query_parser.rb](query_parser.rb) | Contract-driven parsing, typed filtering, deterministic sorting, collection loading/preloading, totals, and offset/keyset modes. |
| [pagination.rb](pagination.rb) | Shared positive-integer bounds, offset application, and offset/cursor link construction. |
| [cursor.rb](cursor.rb) | Base64url JSON cursor encoding, sort-signature validation, boundary serialization, and Arel keyset predicates. |

## For AI Agents

### Working In This Directory

- Request field names only select declared contract entries; SQL column identifiers come from controller policy. Build predicates through Arel and retain escaped literal contains matching.
- Preserve duplicate/shape-conflict detection on raw pairs rather than relying only on Rails params. Family-specific errors must identify the original offending query parameter.
- Keep one effective sort including its tie breaker for query ordering, cursor signatures, predicates, and links. The cursor signature describes sort fields/directions; it is not a cryptographic signature.
- Page size defaults to 20 and clamps at 100. Positive integer/offset checks use signed 64-bit SQL bounds; cursor mode cannot combine page[number] with page[after]/page[before], or paginate nullable sort fields.
- Offset and cursor modes fetch one extra row to determine whether another page exists. Totals perform COUNT only when requested; offset last links depend on totals, while cursor last uses an empty page[before] boundary.
- Keep the cursor's 4096-character predecode limit, value-count/sort checks, and leading-column bound in keyset_predicate. That bound allows the database to seek into an index rather than scan all earlier rows.
- Read backward using reversed database order, then reverse records for the public response. Includes preload the materialized page without N+1 queries.

### Testing Requirements

Run spec/lib/jsonapi/cursor_spec.rb and spec/requests/api/v1/examples_query_spec.rb for shared query changes. Include action-query/reference-resource request specs when contracts or accepted query families change. Follow root full-suite and API-contract checks.

### Common Patterns

QueryResult is a Data value containing loaded scope records, includes, optional total_count, links, and whether include was requested. Pagination helpers share parsing rules with controller concerns; errors are JsonApiError with source.parameter.

## Dependencies

### Internal

query_contract declarations in Api::V1 resource controllers; JsonapiQuery and CrudActions integrate the result into HTTP responses; JsonApiError provides stable error codes.

### External

Active Record/Arel, ActionController parameters, and Ruby Base64, JSON, URI, Time, and Set libraries.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
