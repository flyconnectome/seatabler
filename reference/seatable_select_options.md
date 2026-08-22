# Read and add options for a select column

`seatable_select_options` returns the option names currently defined for
one or more single- or multiple-select columns.
`seatable_add_select_options` adds new options to a column's vocabulary.

## Usage

``` r
seatable_select_options(
  table,
  col = NULL,
  base = NULL,
  con = default_connection()
)

seatable_add_select_options(
  table,
  col,
  options,
  base = NULL,
  con = default_connection()
)
```

## Arguments

- table:

  Name of the table.

- col:

  For `seatable_select_options`, single- or multiple-select column
  name(s); `NULL` (the default) returns every such column. For
  `seatable_add_select_options`, a single column name.

- base:

  Optional base name or `Base` object; discovered from `table` when
  `NULL`.

- con:

  A
  [seatable_connection](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md).

- options:

  Character vector of new option name(s) to add.

## Value

For `seatable_select_options`, a named list of character vectors (one
per column) of option names. For `seatable_add_select_options`, the
SeaTable response, invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
seatable_select_options("neurons", "status", con = con)
seatable_add_select_options("neurons", "status", "reviewed", con = con)
} # }
```
