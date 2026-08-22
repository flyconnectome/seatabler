# Resolve the API token for a connection

Resolve the API token for a connection

## Usage

``` r
seatable_token(con = default_connection(), error = TRUE)
```

## Arguments

- con:

  A
  [seatable_connection](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md).

- error:

  Whether to error (default) or return `NA` when the token environment
  variable is unset.

## Value

The token string, or `NA_character_` when unset and `error = FALSE`.
