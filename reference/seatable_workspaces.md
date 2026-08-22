# List workspaces (and their bases) visible to a connection

List workspaces (and their bases) visible to a connection

## Usage

``` r
seatable_workspaces(con = default_connection())
```

## Arguments

- con:

  A
  [seatable_connection](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md).

## Value

A data.frame with at least `workspace_id` and base `name` columns.
