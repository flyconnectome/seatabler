# Authenticate with a SeaTable server

`seatable_login` opens an authenticated session using the connection's
API token. `seatable_generate_token` mints a fresh permanent user-level
token from your user name and password, makes it available for the
current session and, by default, persists it to `~/.Renviron` for future
sessions.

## Usage

``` r
seatable_login(con = default_connection())

seatable_generate_token(user, pwd, con = default_connection(), persist = TRUE)
```

## Arguments

- con:

  A
  [seatable_connection](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md).

- user, pwd:

  Your SeaTable user name (email) and password, used only to mint a
  token.

- persist:

  Whether to persist the token to `~/.Renviron` so it is available in
  future R sessions (default `TRUE`). Any existing line for the
  connection's `token_envvar` is replaced, otherwise a new line is
  appended, and the token is set for the current session too. With
  `persist = FALSE` nothing is written or set — the token is only
  returned.

## Value

For `seatable_login`, a Python
[`Account`](https://seatable.github.io/seatable-scripts/python/account/)
object (reticulate-wrapped), invisibly. For `seatable_generate_token`,
the token string, invisibly.

## Details

Authentication is by API token, never by password at call time:
`seatable_login` constructs a Python `Account` with no credentials and
sets its token directly, so SeaTable uses that token for every
subsequent call. Call `seatable_generate_token` once to obtain a token;
thereafter the token in the connection's `token_envvar` (or embedded in
the connection object) is all that is needed.

Tokens are per-server, so give each server its own `token_envvar` name
(wrapper packages typically pin one, e.g. `"FLYTABLE_TOKEN"`). With
`persist = TRUE` the token is written to `~/.Renviron` under that name,
replacing any existing line for it.

## Examples

``` r
if (FALSE) { # \dontrun{
con <- seatable_connection("https://cloud.seatable.io/",
                           token_envvar = "BANCTABLE_TOKEN")
seatable_generate_token("me@example.com", "secret", con = con)
seatable_login(con)
} # }
```
