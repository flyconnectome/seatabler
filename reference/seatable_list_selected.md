# Select rows from a SeaTable table by id

Builds and runs a `SELECT ... WHERE <idfield> IN (...)` query for a set
of ids – a convenience over writing the SQL by hand. With no `ids` it
returns the whole table.

## Usage

``` r
seatable_list_selected(
  ids = NULL,
  table,
  fields = "*",
  idfield = NULL,
  base = NULL,
  con = default_connection(),
  ...
)
```

## Arguments

- ids:

  Ids to look up, matched against `idfield`. `NULL` (the default)
  returns every row.

- table:

  Name of the table.

- fields:

  Columns to return: `"*"` (default) for all, a comma-separated string,
  or a character vector of column names (back-quoted for you).

- idfield:

  Column to match `ids` against. Required when `ids` is supplied.

- base:

  Optional base name or `Base` object; discovered from `table` when
  `NULL`.

- con:

  A
  [seatable_connection](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md).

- ...:

  Passed to
  [`seatable_query()`](https://flyconnectome.github.io/seatabler/reference/seatable_query.md)
  (e.g. `limit`, `python`).

## Value

A data.frame of the selected rows and columns.

## Details

This is a generic id lookup: `ids` are matched against `idfield`
verbatim, with no coercion. Consumer packages that key on a domain id
(for example a flywire root id that must be resolved to its current
value first) should do that resolution in their own wrapper before
calling this. Whether values are quoted in the SQL is decided from
`idfield`'s column type (numeric columns are left unquoted).

## See also

[`seatable_query()`](https://flyconnectome.github.io/seatabler/reference/seatable_query.md),
[`seatable_list_rows()`](https://flyconnectome.github.io/seatabler/reference/seatable_list_rows.md)
