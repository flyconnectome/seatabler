# Update or append rows in a SeaTable table

`seatable_update_rows` updates existing rows (matched by their
`_id`/`row_id`), returning `TRUE` on success. `seatable_append_rows`
adds new rows, optionally straight into big data storage.

## Usage

``` r
seatable_update_rows(
  df,
  table,
  base = NULL,
  con = default_connection(),
  append_allowed = TRUE,
  chunksize = 1000L,
  multi_select_cols = NULL,
  allow_new_options = FALSE
)

seatable_append_rows(
  df,
  table,
  base = NULL,
  con = default_connection(),
  bigdata = FALSE,
  chunksize = 1000L,
  multi_select_cols = NULL,
  allow_new_options = FALSE
)
```

## Arguments

- df:

  A data.frame of rows to write. For updates it must carry an `_id` or
  `row_id` column identifying each remote row.

- table:

  Name of the table.

- base:

  Optional base name or `Base` object; discovered from `table` when
  `NULL`.

- con:

  A
  [seatable_connection](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md).

- append_allowed:

  For `seatable_update_rows`, whether rows whose id is missing may be
  appended as new rows rather than raising an error.

- chunksize:

  Split large requests into calls of at most this many rows.

- multi_select_cols:

  Column names to treat as multiple-select (list-per-cell). The default
  `NULL` auto-detects them from column metadata.

- allow_new_options:

  When a multiple-select value is not already an option for its column,
  whether to add it automatically (via
  [`seatable_add_select_options()`](https://flyconnectome.github.io/seatabler/reference/seatable_select_options.md))
  rather than erroring.

- bigdata:

  For `seatable_append_rows`, whether to write straight into big data
  (archived) storage via REST rather than the ordinary grid.

## Value

Logical, invisibly: `TRUE` on success. Failures normally abort with the
SeaTable error message.

## Details

SeaTable keeps a unique `_id` for every row, returned by
[`seatable_query()`](https://flyconnectome.github.io/seatabler/reference/seatable_query.md).
To update, keep that column (named `_id` or `row_id`) in `df`; to append
you do not need it (and are warned if you supply one). Writes are
chunked at `chunksize` rows because the API caps a single call at 1000.

**Multiple-select columns** need care: SeaTable expects a genuine list
of option names per cell, and silently invents a new option from any
bare string it is handed instead. Any column SeaTable reports as
`"multiple-select"` is auto-detected and routed through a list-per-cell
path; pass `multi_select_cols` to override detection. A scalar cell
(`"AB"`, or comma-joined `"AB,CD"`) is accepted as shorthand and split
on commas — symmetric with how such a cell reads back — or supply a
list-column directly (`I(list(c("AB", "CD")))`), which also lets you
write an option name that itself contains a comma. Every resulting value
is checked against the column's existing vocabulary and rejected unless
it is already an option; see `allow_new_options` and
[`seatable_add_select_options()`](https://flyconnectome.github.io/seatabler/reference/seatable_select_options.md).

**Big data** (`bigdata = TRUE`, append only): rows go through the
`add-archived-rows` REST endpoint straight into archived storage, rather
than the ordinary grid via the SDK. This is for bulk loads that would
exceed the base's grid row cap; the base must have big data enabled or
the gateway returns an error. Big data is an append *destination*, not a
property of the table (a table can hold both grid and archived rows) —
see
[`seatable_archive_rows()`](https://flyconnectome.github.io/seatabler/reference/seatable_archive_rows.md).

## See also

[`seatable_query()`](https://flyconnectome.github.io/seatabler/reference/seatable_query.md)
to read rows back,
[`seatable_archive_rows()`](https://flyconnectome.github.io/seatabler/reference/seatable_archive_rows.md)
to move rows into and out of big data storage.

## Examples

``` r
if (FALSE) { # \dontrun{
rows <- seatable_query("SELECT _id, name FROM neurons LIMIT 2", con = con)
rows$name <- toupper(rows$name)
seatable_update_rows(rows, "neurons", con = con)

seatable_append_rows(data.frame(name = "new cell"), "neurons", con = con)
} # }
```
