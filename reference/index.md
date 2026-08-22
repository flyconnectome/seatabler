# Package index

## Package

- [`seatabler`](https://flyconnectome.github.io/seatabler/reference/seatabler-package.md)
  [`seatabler-package`](https://flyconnectome.github.io/seatabler/reference/seatabler-package.md)
  : seatabler: a generic R client for SeaTable servers

## Connections

Configure and resolve the server connection (URL + token + workspace).

- [`seatable_connection()`](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md)
  [`is_seatable_connection()`](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md)
  : Create a connection to a SeaTable server
- [`default_connection()`](https://flyconnectome.github.io/seatabler/reference/default_connection.md)
  : The current default connection
- [`set_default_connection()`](https://flyconnectome.github.io/seatabler/reference/set_default_connection.md)
  : Set (or clear) the default connection
- [`with_connection()`](https://flyconnectome.github.io/seatabler/reference/with_connection.md)
  : Evaluate an expression with a temporary default connection
- [`seatable_token()`](https://flyconnectome.github.io/seatabler/reference/seatable_token.md)
  : Resolve the API token for a connection

## Authentication

Import the Python SDK and obtain / mint API tokens.

- [`seatable_module()`](https://flyconnectome.github.io/seatabler/reference/seatable_module.md)
  : Import the seatable_api Python module
- [`seatable_login()`](https://flyconnectome.github.io/seatabler/reference/seatable_login.md)
  [`seatable_generate_token()`](https://flyconnectome.github.io/seatabler/reference/seatable_login.md)
  : Authenticate with a SeaTable server

## Bases, workspaces and tables

- [`seatable_base()`](https://flyconnectome.github.io/seatabler/reference/seatable_base.md)
  : Get a SeaTable base object
- [`seatable_workspaces()`](https://flyconnectome.github.io/seatabler/reference/seatable_workspaces.md)
  : List workspaces (and their bases) visible to a connection
- [`seatable_workspace_id()`](https://flyconnectome.github.io/seatabler/reference/seatable_workspace_id.md)
  : Find the workspace containing a base
- [`seatable_alltables()`](https://flyconnectome.github.io/seatabler/reference/seatable_alltables.md)
  : List all tables across all bases visible to a connection

## Querying and reading rows

- [`seatable_query()`](https://flyconnectome.github.io/seatabler/reference/seatable_query.md)
  : Run a SQL query against a SeaTable server
- [`seatable_list_rows()`](https://flyconnectome.github.io/seatabler/reference/seatable_list_rows.md)
  : List rows from a SeaTable table
- [`seatable_list_selected()`](https://flyconnectome.github.io/seatabler/reference/seatable_list_selected.md)
  : Select rows from a SeaTable table by id

## Writing rows

Batch append / update / delete, with big-data batching.

- [`seatable_update_rows()`](https://flyconnectome.github.io/seatabler/reference/seatable_update_rows.md)
  [`seatable_append_rows()`](https://flyconnectome.github.io/seatabler/reference/seatable_update_rows.md)
  : Update or append rows in a SeaTable table
- [`seatable_delete_rows()`](https://flyconnectome.github.io/seatabler/reference/seatable_delete_rows.md)
  : Delete rows from a SeaTable table

## Big-data archive

- [`seatable_archive_rows()`](https://flyconnectome.github.io/seatabler/reference/seatable_archive_rows.md)
  [`seatable_unarchive_rows()`](https://flyconnectome.github.io/seatabler/reference/seatable_archive_rows.md)
  : Move rows into and out of SeaTable big data storage

## Columns and schema

- [`seatable_columns()`](https://flyconnectome.github.io/seatabler/reference/seatable_columns.md)
  : Column names, types and default R types for a table
- [`seatable_add_column()`](https://flyconnectome.github.io/seatabler/reference/seatable_add_column.md)
  [`seatable_add_columns()`](https://flyconnectome.github.io/seatabler/reference/seatable_add_column.md)
  : Add columns to a SeaTable table
- [`seatable_delete_column()`](https://flyconnectome.github.io/seatabler/reference/seatable_delete_column.md)
  : Delete a column from a SeaTable table
- [`seatable_select_options()`](https://flyconnectome.github.io/seatabler/reference/seatable_select_options.md)
  [`seatable_add_select_options()`](https://flyconnectome.github.io/seatabler/reference/seatable_select_options.md)
  : Read and add options for a select column

## Snapshots

- [`seatable_snapshots()`](https://flyconnectome.github.io/seatabler/reference/seatable_snapshots.md)
  : List the snapshots of a SeaTable base

## REST transport

Low-level api-gateway helpers behind the big-data and snapshot
functions.

- [`seatable_rest()`](https://flyconnectome.github.io/seatabler/reference/seatable_rest.md)
  [`seatable_base_rest()`](https://flyconnectome.github.io/seatabler/reference/seatable_rest.md)
  : Call a SeaTable REST endpoint directly
