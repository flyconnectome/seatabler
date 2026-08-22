# Add columns to a SeaTable table

`seatable_add_column()` inserts a single new column;
`seatable_add_columns()` adds several at once from a data frame of names
and types, skipping any that already exist. Together they let a
migration script bring a table's schema up to date without touching the
SeaTable web interface.

## Usage

``` r
seatable_add_column(
  table,
  column_name,
  column_type = "text",
  base = NULL,
  con = default_connection(),
  column_data = NULL,
  column_key = NULL
)

seatable_add_columns(
  table,
  columns,
  base = NULL,
  con = default_connection(),
  progress = TRUE
)
```

## Arguments

- table:

  Name of the table to add to.

- column_name:

  Name of the new column.

- column_type:

  SeaTable column type (see Details). Defaults to `"text"`.

- base:

  Optional base name or `Base` object; discovered from `table` when
  `NULL`.

- con:

  A
  [seatable_connection](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md).

- column_data:

  Optional list of type-specific column settings, e.g. the `options` of
  a select column.

- column_key:

  Optional key of an existing column, to position the new column
  immediately after it.

- columns:

  A data frame with `name` and `type` columns — the same shape
  [`seatable_columns()`](https://flyconnectome.github.io/seatabler/reference/seatable_columns.md)
  returns, so the schema of one table can be replayed onto another.

- progress:

  Whether to report each column as it is added.

## Value

For `seatable_add_column()`, the new column's definition, invisibly. For
`seatable_add_columns()`, the subset of `columns` that was actually
added, invisibly.

## Details

`column_type` uses SeaTable's own vocabulary — most commonly `"text"`,
`"long-text"`, `"number"`, `"date"`, `"checkbox"`, `"single-select"` or
`"multiple-select"`; see
<https://api.seatable.io/reference/insert-column-2> for the full list.

Options for a select column, and other type-specific settings, go in
`column_data`, e.g.
`column_data = list(options = list(list(name = "yes"), list(name = "no")))`.

## Examples

``` r
if (FALSE) { # \dontrun{
seatable_add_column("neurons", "cell_type", con = con)
seatable_add_column("neurons", "n_synapses", "number", con = con)

# Bring a table up to a target schema, adding only what is missing
seatable_add_columns("neurons",
  data.frame(name = c("side", "notes"), type = c("text", "long-text")),
  con = con)
} # }
```
