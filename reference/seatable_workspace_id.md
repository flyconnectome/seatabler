# Find the workspace containing a base

Resolves the workspace id for a named base. Some SeaTable REST endpoints
(snapshots, for instance) are addressed by workspace rather than by base
uuid, and users rarely know their workspace ids.

## Usage

``` r
seatable_workspace_id(base_name, con = default_connection())
```

## Arguments

- base_name:

  Name of the base.

- con:

  A
  [seatable_connection](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md).
  When the connection already carries a `workspace_id` that is returned
  unchanged.

## Value

The workspace id, as a character string.
