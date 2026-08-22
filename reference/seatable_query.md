# Run a SQL query against a SeaTable server

Run a SQL query against a SeaTable server

## Usage

``` r
seatable_query(
  sql,
  con = default_connection(),
  limit = 100000L,
  base = NULL,
  python = FALSE,
  convert = TRUE,
  paginate = TRUE,
  chunksize = NULL,
  retries = 3L,
  progress = interactive()
)
```

## Arguments

- sql:

  A single SQL `SELECT` statement. The table name is parsed from the
  `FROM` clause.

- con:

  A
  [seatable_connection](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md).

- limit:

  Maximum rows to return. The default fetches all rows, paginating as
  needed.

- base:

  Optional base name or `Base` object; discovered from the table name
  when `NULL`.

- python:

  If `TRUE`, return the raw pandas `DataFrame` instead of an R
  `data.frame`.

- convert:

  Passed to the SeaTable Python `query` call.

- paginate:

  Whether to page through large results automatically (default `TRUE`).
  SeaTable's SQL endpoint silently caps a single call at a
  server-specific maximum; pagination returns the full result.

- chunksize:

  Advanced: force `LIMIT`/`OFFSET` paging in fixed windows of this size.
  The default `NULL` auto-detects the server's per-call cap.

- retries:

  Number of times to retry a page that fails because the server is
  rate-limiting us (HTTP 429), with exponential backoff between
  attempts. Long paginated reads are the usual way to hit a quota, and
  losing the whole read to one throttled page is expensive. Set to `0`
  to fail fast.

- progress:

  Whether to report each page of a paginated read as it arrives.
  Defaults to `TRUE` in an interactive session. Reading a large table
  takes minutes, and silence is hard to distinguish from a hang.

## Value

An R `data.frame` (or a pandas `DataFrame` when `python = TRUE`). If a
paginated read stops early because a page kept failing, the rows read so
far are returned along with a warning saying where it stopped, rather
than throwing away a read that may have taken minutes.

## Examples

``` r
if (FALSE) { # \dontrun{
con <- seatable_connection("https://cloud.seatable.io/", "BANCTABLE_TOKEN",
                           workspace_id = "57832")
seatable_query("SELECT * FROM banc_meta", con = con)
} # }
```
