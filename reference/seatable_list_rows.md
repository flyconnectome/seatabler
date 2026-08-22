# List rows from a SeaTable table

Reads rows through SeaTable's `list_rows` API (rather than SQL),
optionally restricted to a view and ordered by a column. Returns an R
`data.frame`, or the raw pandas `DataFrame` when `python = TRUE`.

## Usage

``` r
seatable_list_rows(
  table,
  base = NULL,
  con = default_connection(),
  view_name = NULL,
  order_by = NULL,
  desc = FALSE,
  start = 0L,
  limit = Inf,
  python = FALSE,
  chunksize = NULL
)
```

## Arguments

- table:

  Name of the table.

- base:

  Optional base name or `Base` object; discovered from `table` when
  `NULL`.

- con:

  A
  [seatable_connection](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md).

- view_name:

  Optional view limiting the rows/columns returned.

- order_by:

  Optional column name to order by.

- desc:

  Whether to sort descending (default ascending).

- start:

  Row offset to start from (0-based).

- limit:

  Maximum rows to return; the default `Inf` returns all rows.

- python:

  Whether to return the pandas `DataFrame` rather than an R
  `data.frame`.

- chunksize:

  Advanced: rows to request per call. The default `NULL` chooses a size
  from the column count (SeaTable allows roughly one million cells per
  request).

## Value

An R `data.frame`, or a pandas `DataFrame` when `python = TRUE`.

## Details

The `list_rows` endpoint caps the number of rows per request, and that
cap is server-configurable with no API to discover it, so a page coming
back shorter than requested does **not** signal the end of the table –
only an empty page does. Rows are therefore fetched in chunks until an
empty page (or `limit`) is reached, then concatenated once and coerced
together, so multiple-select and other list columns flatten uniformly
across chunks.

## See also

[`seatable_query()`](https://flyconnectome.github.io/seatabler/reference/seatable_query.md),
[`seatable_list_selected()`](https://flyconnectome.github.io/seatabler/reference/seatable_list_selected.md)
