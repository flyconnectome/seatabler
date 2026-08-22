# The current default connection

Returns the connection registered with
[`set_default_connection()`](https://flyconnectome.github.io/seatabler/reference/set_default_connection.md),
or one constructed from the `seatabler.url`, `seatabler.token_envvar`
and `seatabler.workspace_id` options. Errors with guidance if no server
URL is available.

Generic `seatable_*` functions default their `con` argument to this, so
an interactive user can set a default once and then omit `con`. Wrapper
packages instead pass an explicit connection so their end users never
need to configure anything.

## Usage

``` r
default_connection()
```

## Value

A
[seatable_connection](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md).
