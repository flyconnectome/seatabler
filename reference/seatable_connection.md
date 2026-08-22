# Create a connection to a SeaTable server

A `seatable_connection` captures everything needed to reach a particular
SeaTable server: its URL, the environment variable holding your API
token, and (optionally) the workspace id and cache directory. It is the
single place server configuration lives, so downstream functions and
wrapper packages can bind one connection rather than passing
URL/token/workspace arguments around.

## Usage

``` r
seatable_connection(
  url,
  token = NULL,
  token_envvar = getOption("seatabler.token_envvar", "SEATABLE_TOKEN"),
  workspace_id = NULL,
  cachedir = getOption("seatabler.cachedir", NULL),
  name = NULL
)

is_seatable_connection(x)
```

## Arguments

- url:

  Base URL of the SeaTable server (e.g. `"https://cloud.seatable.io/"`).
  Required — there is no default server.

- token:

  Optional API token string embedded directly in the connection. When
  supplied it takes precedence over `token_envvar`. It is redacted by
  the print method, but is still an ordinary list element — do not
  commit connections carrying an embedded token to shared repositories.

- token_envvar:

  Name of the environment variable holding the API token, used when
  `token` is not supplied. Defaults to the `seatabler.token_envvar`
  option, or `"SEATABLE_TOKEN"`.

- workspace_id:

  Optional workspace id (character or numeric). When `NULL` it is
  discovered from the base name where possible.

- cachedir:

  Optional per-connection cache directory. When `NULL` the
  `seatabler.cachedir` option is used.

- name:

  Optional short human-readable label for the connection.

- x:

  An object to test / print.

## Value

An object of class `seatable_connection`.

## Details

By default the token itself is not stored in the object — only the name
of the environment variable that holds it (`token_envvar`), resolved
fresh at call time by
[`seatable_token()`](https://flyconnectome.github.io/seatabler/reference/seatable_token.md).
You may instead embed a literal `token`, which is convenient when
talking to several servers (each needs its own token); the print method
redacts it.

## Examples

``` r
con <- seatable_connection(
  url = "https://cloud.seatable.io/",
  token_envvar = "BANCTABLE_TOKEN",
  workspace_id = "57832")
con
#> <seatable_connection>
#>   url:          https://cloud.seatable.io/
#>   token_envvar: BANCTABLE_TOKEN (not set)
#>   workspace_id: 57832
#> 
```
