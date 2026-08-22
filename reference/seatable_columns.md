# Column names, types and default R types for a table

Column names, types and default R types for a table

## Usage

``` r
seatable_columns(
  table,
  base = NULL,
  con = default_connection(),
  include_key = FALSE
)
```

## Arguments

- table:

  Table name.

- base:

  Optional base name or `Base` object; discovered from `table` when
  `NULL`.

- con:

  A
  [seatable_connection](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md).

- include_key:

  Whether to include the internal SeaTable column `key` (useful for
  schema operations and for debugging API errors that reference keys).
  Defaults to `FALSE`.

## Value

A data.frame with `name`, `type`, `rtype` and (optionally) `key`.
