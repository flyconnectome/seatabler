# Delete rows from a SeaTable table

Deletes rows by their SeaTable `_id`. Defaults to a dry run that returns
the ids it *would* delete without touching the server, so you can check
the selection first.

## Usage

``` r
seatable_delete_rows(
  ids,
  table,
  base = NULL,
  con = default_connection(),
  DryRun = TRUE
)
```

## Arguments

- ids:

  A character vector of row `_id`s, or a data.frame with an `_id` column
  (as returned by
  [`seatable_query()`](https://flyconnectome.github.io/seatabler/reference/seatable_query.md)).
  Duplicates are ignored.

- table:

  Name of the table.

- base:

  Optional base name or `Base` object; discovered from `table` when
  `NULL`.

- con:

  A
  [seatable_connection](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md).

- DryRun:

  When `TRUE` (the default) no rows are deleted; the ids that would be
  deleted are returned. Pass `FALSE` to actually delete.

## Value

With `DryRun = TRUE`, the character vector of ids. With
`DryRun = FALSE`, the number of rows the server reports as deleted (a
warning is raised if that is fewer than requested).

## See also

[`seatable_query()`](https://flyconnectome.github.io/seatabler/reference/seatable_query.md),
[`seatable_update_rows()`](https://flyconnectome.github.io/seatabler/reference/seatable_update_rows.md)
