# Move rows into and out of SeaTable big data storage

SeaTable caps the number of rows a base holds in its ordinary grid;
archiving moves rows into "big data" storage, which is much larger and
still queryable with
[`seatable_query()`](https://flyconnectome.github.io/seatabler/reference/seatable_query.md),
at the cost of no longer being editable in the web interface.
`seatable_archive_rows()` moves rows out of the grid,
`seatable_unarchive_rows()` brings them back.

## Usage

``` r
seatable_archive_rows(
  table,
  view_name = NULL,
  view_id = NULL,
  base = NULL,
  con = default_connection()
)

seatable_unarchive_rows(
  table,
  row_ids,
  base = NULL,
  con = default_connection()
)
```

## Arguments

- table:

  Name of the table.

- view_name:

  Name of the view whose rows should be archived. Supply exactly one of
  `view_name` or `view_id`.

- view_id:

  Id of the view whose rows should be archived.

- base:

  Optional base name or `Base` object; discovered from `table` when
  `NULL`.

- con:

  A
  [seatable_connection](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md).

- row_ids:

  Character vector of row ids (the `_id` column) to unarchive.

## Value

The SeaTable response, invisibly.

## Details

The two directions select rows differently, because the API does.
Archiving takes a **view**: make a view holding exactly the rows you
want archived (a filtered view is the usual way) and name it. Earlier
versions of the endpoint accepted a SQL `WHERE` clause; that is gone,
and a view is now the only way to choose rows. Unarchiving instead takes
explicit `row_ids`, which you can get by querying the archived rows with
`seatable_query("SELECT _id FROM ...")`.

Archiving is not easily undone in bulk — you need the row ids to bring
rows back — so check the view holds what you expect before calling.

## Examples

``` r
if (FALSE) { # \dontrun{
# Archive everything in the (filtered) view called "to archive"
seatable_archive_rows("neurons", view_name = "to archive", con = con)

# ...and bring two rows back
seatable_unarchive_rows("neurons",
  row_ids = c("FoDxhChYQSycLm88JZ11RA", "Yb3kQ0rRQ0aXk3lWk0mWLQ"),
  con = con)
} # }
```
