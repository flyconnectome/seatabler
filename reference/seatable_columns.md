# Column names, types and default R types for a table

Column names, types and default R types for a table

## Usage

``` r
seatable_columns(
  table,
  base = NULL,
  con = default_connection(),
  include_key = FALSE,
  cached = TRUE
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

- cached:

  Whether to use the cached schema (the default). The schema is memoised
  for an hour to save a metadata round-trip on every read; pass `FALSE`
  to force a refresh after changing the schema outside this session.

## Value

A data.frame with `name`, `type`, `rtype`, `data` and (optionally)
`key`.

## Details

The returned data.frame also carries a `data` list-column with each
column's raw SeaTable metadata (e.g. a select column's `options`, a date
column's `format`), which the read paths use to coerce results and
[`seatable_select_options()`](https://flyconnectome.github.io/seatabler/reference/seatable_select_options.md)
uses to list option names.
