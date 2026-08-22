# Evaluate an expression with a temporary default connection

Evaluate an expression with a temporary default connection

## Usage

``` r
with_connection(con, expr)
```

## Arguments

- con:

  A
  [seatable_connection](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md)
  to use as the default for the duration of `expr`.

- expr:

  Expression to evaluate.

## Value

The value of `expr`.

## Examples

``` r
if (FALSE) { # \dontrun{
with_connection(seatable_connection("https://cloud.seatable.io/"), {
  seatable_query("SELECT * FROM banc_meta")
})
} # }
```
