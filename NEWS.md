# seatabler 0.2.1

* Restored the schema-aware result coercion that was dropped when
  `flytable_query` became `seatable_query`: `nat.python::pandas2df()` handles
  only the generic pandas -> R conversion (and leaves multiple-select cells as
  list-columns, having no SeaTable schema), so `flytable2df()` /
  `flytable_fix_coltypes()` / `flytable_parse_date()` are ported over as
  internal `st_coerce_df()` and applied on every read path. This collapses
  multiple-select columns to character vectors and restores SeaTable column
  types (numbers, checkboxes, dates).
* `seatable_query()` and `seatable_list_rows()` gain a `collapse_lists` argument
  (default `TRUE`, comma-joining; `FALSE` keeps list-columns; a string sets the
  separator); it also passes through `seatable_list_selected()`.
* Restored the memoisation of `seatable_columns()` (schema cached for an hour,
  invalidated after schema mutations; `cached = FALSE` forces a refresh), which
  had been dropped, so paginated reads no longer refetch the schema per page.
  It now also carries the per-column `data` metadata, so date columns parse with
  their declared format and `seatable_select_options()` reads option names from
  the cached schema rather than a fresh `get_metadata()` call.

# seatabler 0.2.0

First tagged release. A server-agnostic R client for SeaTable, factored out of
the seatable code embedded in fafbseg (and independently in bancr).

## Connections
* First-class `seatable_connection()` objects carrying URL, token *environment
  variable name* (never the token value) and workspace, with
  `default_connection()` / `set_default_connection()` / `with_connection()` for
  a resolvable session default. Wrapper packages bind one connection so end
  users never pass URL/token/workspace triples.

## Core functionality
* Authentication by API token: `seatable_module()`, `seatable_login()`,
  `seatable_generate_token()`.
* Base/workspace/table resolution: `seatable_base()`, `seatable_workspaces()`,
  `seatable_workspace_id()`, `seatable_alltables()`.
* Querying and reading: `seatable_query()` (paginated), `seatable_list_rows()`,
  `seatable_list_selected()` (generic, no ID coercion).
* Writing: `seatable_update_rows()`, `seatable_append_rows()`,
  `seatable_delete_rows()`, with big-data batching.
* Columns and schema: `seatable_columns()`, `seatable_add_column(s)()`,
  `seatable_delete_column()`, `seatable_select_options()` /
  `seatable_add_select_options()` for multi-select columns.
* Big-data archive/unarchive: `seatable_archive_rows()`,
  `seatable_unarchive_rows()`.
* Snapshot listing: `seatable_snapshots()`.
* REST/JWT transport (`seatable_rest()`, `seatable_base_rest()`) behind the
  big-data and snapshot helpers, using httr2 against the api-gateway.

## Python
* Python environment management and pandas→R conversion are delegated to
  nat.python (`check_module()` / `simple_python()` / `pandas2df()`) rather than
  fafbseg, avoiding a dependency cycle. Provision in one step with
  `nat.python::simple_python("minimal", pkgs = "seatable_api")`.
