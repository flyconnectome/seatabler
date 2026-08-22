# List all tables across all bases visible to a connection

List all tables across all bases visible to a connection

## Usage

``` r
seatable_alltables(con = default_connection())
```

## Arguments

- con:

  A
  [seatable_connection](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md).

## Value

A data.frame with `base_name`, `workspace_id`, table `name` and `_id`.
