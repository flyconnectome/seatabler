# Changelog

## seatabler 0.2.0

First tagged release. A server-agnostic R client for SeaTable, factored
out of the seatable code embedded in fafbseg (and independently in
bancr).

### Connections

- First-class
  [`seatable_connection()`](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md)
  objects carrying URL, token *environment variable name* (never the
  token value) and workspace, with
  [`default_connection()`](https://flyconnectome.github.io/seatabler/reference/default_connection.md)
  /
  [`set_default_connection()`](https://flyconnectome.github.io/seatabler/reference/set_default_connection.md)
  /
  [`with_connection()`](https://flyconnectome.github.io/seatabler/reference/with_connection.md)
  for a resolvable session default. Wrapper packages bind one connection
  so end users never pass URL/token/workspace triples.

### Core functionality

- Authentication by API token:
  [`seatable_module()`](https://flyconnectome.github.io/seatabler/reference/seatable_module.md),
  [`seatable_login()`](https://flyconnectome.github.io/seatabler/reference/seatable_login.md),
  [`seatable_generate_token()`](https://flyconnectome.github.io/seatabler/reference/seatable_login.md).
- Base/workspace/table resolution:
  [`seatable_base()`](https://flyconnectome.github.io/seatabler/reference/seatable_base.md),
  [`seatable_workspaces()`](https://flyconnectome.github.io/seatabler/reference/seatable_workspaces.md),
  [`seatable_workspace_id()`](https://flyconnectome.github.io/seatabler/reference/seatable_workspace_id.md),
  [`seatable_alltables()`](https://flyconnectome.github.io/seatabler/reference/seatable_alltables.md).
- Querying and reading:
  [`seatable_query()`](https://flyconnectome.github.io/seatabler/reference/seatable_query.md)
  (paginated),
  [`seatable_list_rows()`](https://flyconnectome.github.io/seatabler/reference/seatable_list_rows.md),
  [`seatable_list_selected()`](https://flyconnectome.github.io/seatabler/reference/seatable_list_selected.md)
  (generic, no ID coercion).
- Writing:
  [`seatable_update_rows()`](https://flyconnectome.github.io/seatabler/reference/seatable_update_rows.md),
  [`seatable_append_rows()`](https://flyconnectome.github.io/seatabler/reference/seatable_update_rows.md),
  [`seatable_delete_rows()`](https://flyconnectome.github.io/seatabler/reference/seatable_delete_rows.md),
  with big-data batching.
- Columns and schema:
  [`seatable_columns()`](https://flyconnectome.github.io/seatabler/reference/seatable_columns.md),
  `seatable_add_column(s)()`,
  [`seatable_delete_column()`](https://flyconnectome.github.io/seatabler/reference/seatable_delete_column.md),
  [`seatable_select_options()`](https://flyconnectome.github.io/seatabler/reference/seatable_select_options.md)
  /
  [`seatable_add_select_options()`](https://flyconnectome.github.io/seatabler/reference/seatable_select_options.md)
  for multi-select columns.
- Big-data archive/unarchive:
  [`seatable_archive_rows()`](https://flyconnectome.github.io/seatabler/reference/seatable_archive_rows.md),
  [`seatable_unarchive_rows()`](https://flyconnectome.github.io/seatabler/reference/seatable_archive_rows.md).
- Snapshot listing:
  [`seatable_snapshots()`](https://flyconnectome.github.io/seatabler/reference/seatable_snapshots.md).
- REST/JWT transport
  ([`seatable_rest()`](https://flyconnectome.github.io/seatabler/reference/seatable_rest.md),
  [`seatable_base_rest()`](https://flyconnectome.github.io/seatabler/reference/seatable_rest.md))
  behind the big-data and snapshot helpers, using httr2 against the
  api-gateway.

### Python

- Python environment management and pandas→R conversion are delegated to
  nat.python (`check_module()` / `simple_python()` / `pandas2df()`)
  rather than fafbseg, avoiding a dependency cycle. Provision in one
  step with
  `nat.python::simple_python("minimal", pkgs = "seatable_api")`.
