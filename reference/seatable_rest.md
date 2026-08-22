# Call a SeaTable REST endpoint directly

Low-level access to SeaTable's HTTP API, for endpoints the Python SDK
does not expose. `seatable_rest()` talks to the *account* API (paths
under `api/v2.1/`, authenticated with the connection's API token);
`seatable_base_rest()` talks to a *base* through the API gateway (paths
under `api-gateway/api/v2/dtables/<base-uuid>/`, authenticated with that
base's JWT).

## Usage

``` r
seatable_rest(
  path,
  con = default_connection(),
  method = NULL,
  body = NULL,
  query = NULL,
  retries = 3L,
  parse = TRUE
)

seatable_base_rest(
  path,
  base = NULL,
  con = default_connection(),
  method = NULL,
  body = NULL,
  query = NULL,
  table = NULL,
  retries = 3L,
  parse = TRUE
)
```

## Arguments

- path:

  Endpoint path relative to the server root (`seatable_rest()`) or to
  `api-gateway/api/v2/dtables/<base-uuid>/` (`seatable_base_rest()`).

- con:

  A
  [seatable_connection](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md).

- method:

  HTTP method. Defaults to `"GET"`, or `"POST"` when a `body` is
  supplied.

- body:

  A list encoded as the JSON request body, or `NULL`.

- query:

  A named list of URL query parameters, or `NULL`.

- retries:

  Number of times to retry a 429 or 5xx response.

- parse:

  Whether to parse the JSON response (default) or return the raw `httr2`
  response object.

- base:

  A `Base` object from
  [`seatable_base()`](https://flyconnectome.github.io/seatabler/reference/seatable_base.md),
  or a base name. When `NULL`, the base is discovered from `table`.

- table:

  Name of a table whose base to use, when `base` is not a `Base` object.
  Lets callers reach a base endpoint given only a table name.

## Value

The parsed JSON response as an R list, or an `httr2_response` when
`parse = FALSE`. Endpoints with an empty body return `NULL`.

## Details

These are the transport behind
[`seatable_archive_rows()`](https://flyconnectome.github.io/seatabler/reference/seatable_archive_rows.md),
[`seatable_unarchive_rows()`](https://flyconnectome.github.io/seatabler/reference/seatable_archive_rows.md)
and
[`seatable_snapshots()`](https://flyconnectome.github.io/seatabler/reference/seatable_snapshots.md),
and are exported so that consumer packages can reach endpoints seatabler
does not yet wrap without reimplementing authentication.

Two details are easy to get wrong and are handled here. Requests are
forced onto HTTP/1.1 (curl's `CURL_HTTP_VERSION_1_1`, numeric value 2),
because SeaTable's gateway can return HTTP/2 framing errors under load.
And JSON bodies encode `NA` as `null` rather than the string `"NA"`,
which SeaTable rejects in number columns.

Rate-limited (429) and server-error (5xx) responses are retried with
exponential backoff; other error statuses raise an error carrying
SeaTable's own `error_message` where it supplies one.

## Examples

``` r
if (FALSE) { # \dontrun{
con <- seatable_connection("https://cloud.seatable.io/", token_envvar = "MY_TOKEN")

# An account endpoint: which bases can I see?
seatable_rest("api/v2.1/dtables/", con = con)

# A base endpoint, authenticated with the base JWT
base <- seatable_base("my_base", con = con)
seatable_base_rest("metadata/", base = base, con = con)
} # }
```
