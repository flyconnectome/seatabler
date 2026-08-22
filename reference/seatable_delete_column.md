# Delete a column from a SeaTable table

Removes a column and all the data in it. This cannot be undone, so
`seatable_delete_column()` takes the internal column *key* rather than
its name: looking the key up with
`seatable_columns(table, include_key = TRUE)` is a deliberate speed
bump.

## Usage

``` r
seatable_delete_column(
  table,
  column_key,
  base = NULL,
  con = default_connection()
)
```

## Arguments

- table:

  Name of the table.

- column_key:

  Internal key of the column to delete (e.g. `"8blF"`), from
  `seatable_columns(table, include_key = TRUE)`.

- base:

  Optional base name or `Base` object; discovered from `table` when
  `NULL`.

- con:

  A
  [seatable_connection](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md).

## Value

The SeaTable response, invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
cols <- seatable_columns("neurons", include_key = TRUE, con = con)
key <- cols$key[cols$name == "scratch"]
seatable_delete_column("neurons", key, con = con)
} # }
```
