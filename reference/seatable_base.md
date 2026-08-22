# Get a SeaTable base object

Get a SeaTable base object

## Usage

``` r
seatable_base(
  base_name = NULL,
  table = NULL,
  con = default_connection(),
  workspace_id = con$workspace_id,
  cached = TRUE
)
```

## Arguments

- base_name:

  Name of the base. Optional if `table` is supplied and unique across
  the server.

- table:

  Name of a table whose base you want. Used to discover the base when
  `base_name` is not given.

- con:

  A
  [seatable_connection](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md).

- workspace_id:

  Workspace id. Defaults to the connection's `workspace_id`; discovered
  from `base_name` when `NULL`.

- cached:

  Whether to use the memoised base object.

## Value

A Python SeaTable `Base` object (reticulate-wrapped).
