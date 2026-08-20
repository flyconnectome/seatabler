# Authentication / Python SDK bootstrap.
#
# seatabler talks to SeaTable via the official `seatable_api` Python package
# through reticulate. Python-environment management is delegated to nat.python
# (check_module / simple_python); here we obtain the module through that gate and
# authenticate.

#' Import the seatable_api Python module
#'
#' @description Imports the `seatable_api` Python module, on which every other
#'   seatabler function relies. The result is cached for the session.
#'
#' @details seatabler depends on nat.python for Python environment management, so
#'   `seatable_module()` is a thin wrapper over
#'   [nat.python::check_module()]. That checks whether each module is installed
#'   (from distribution metadata, without importing), imports it, and on absence
#'   either offers to install it — interactively, via
#'   [nat.python::simple_python()] into the managed natverse Python environment —
#'   or errors with guidance. Both `seatable_api` and `pandas` are ensured:
#'   seatabler moves pandas `DataFrame`s around directly and converts them with
#'   [nat.python::pandas2df()], but `seatable_api` does not itself depend on
#'   pandas, so a `seatable_api`-only install would fail at the first pandas
#'   import. To set Python up in one step beforehand, run
#'   `nat.python::simple_python("minimal", pkgs = "seatable_api")` — the
#'   `"minimal"` bundle installs pandas and `pkgs` adds `seatable_api` — or
#'   `nat.python::simple_python("basic")` if you also want the wider natverse
#'   Python stack.
#'
#' @return The imported `seatable_api` module.
#' @export
seatable_module <- function() {
  # seatable_api does not depend on pandas, but seatabler converts pandas frames
  # everywhere (queries, list_rows, append) and via nat.python::pandas2df, so a
  # bare seatable_api install fails at the first import("pandas"): ensure both.
  nat.python::check_module("pandas")
  nat.python::check_module(
    "seatable_api",
    docs_url = "https://seatable.github.io/seatable-scripts/python/")
}

#' Authenticate with a SeaTable server
#'
#' @description `seatable_login` opens an authenticated session using the
#'   connection's API token. `seatable_generate_token` mints a fresh permanent
#'   user-level token from your user name and password, makes it available for
#'   the current session and, by default, persists it to `~/.Renviron` for
#'   future sessions.
#'
#' @details Authentication is by API token, never by password at call time:
#'   `seatable_login` constructs a Python `Account` with no credentials and sets
#'   its token directly, so SeaTable uses that token for every subsequent call.
#'   Call `seatable_generate_token` once to obtain a token; thereafter the token
#'   in the connection's `token_envvar` (or embedded in the connection object) is
#'   all that is needed.
#'
#'   Tokens are per-server, so give each server its own `token_envvar` name
#'   (wrapper packages typically pin one, e.g. `"FLYTABLE_TOKEN"`). With
#'   `persist = TRUE` the token is written to `~/.Renviron` under that name,
#'   replacing any existing line for it.
#'
#' @param con A [seatable_connection].
#' @return For `seatable_login`, a Python
#'   \href{https://seatable.github.io/seatable-scripts/python/account/}{`Account`}
#'   object (reticulate-wrapped), invisibly. For `seatable_generate_token`, the
#'   token string, invisibly.
#' @export
#' @examples
#' \dontrun{
#' con <- seatable_connection("https://cloud.seatable.io/",
#'                            token_envvar = "BANCTABLE_TOKEN")
#' seatable_generate_token("me@example.com", "secret", con = con)
#' seatable_login(con)
#' }
seatable_login <- function(con = default_connection()) {
  con <- as_connection(con)
  st <- seatable_module()
  token <- seatable_token(con)  # errors if unset
  # Authenticate by token, not password: build an Account with no credentials
  # and set its token directly; SeaTable uses it for all subsequent calls.
  ac <- reticulate::py_call(st$Account, login_name = NULL, password = NULL,
                            server_url = con$url)
  ac$token <- token
  invisible(ac)
}

#' @rdname seatable_login
#' @param user,pwd Your SeaTable user name (email) and password, used only to
#'   mint a token.
#' @param persist Whether to persist the token to `~/.Renviron` so it is
#'   available in future R sessions (default `TRUE`). Any existing line for the
#'   connection's `token_envvar` is replaced, otherwise a new line is appended,
#'   and the token is set for the current session too. With `persist = FALSE`
#'   nothing is written or set — the token is only returned.
#' @export
seatable_generate_token <- function(user, pwd, con = default_connection(),
                                    persist = TRUE) {
  con <- as_connection(con)
  st <- seatable_module()
  ac <- reticulate::py_call(st$Account, login_name = user, password = pwd,
                            server_url = con$url)
  ac$auth()
  token <- ac$token
  if (isTRUE(persist)) {
    # Immediately usable this session; .Renviron is only read at startup.
    do.call(Sys.setenv, structure(list(token), names = con$token_envvar))
    renviron_set(con$token_envvar, token)
  }
  invisible(token)
}

# Replace-or-append `name='value'` in ~/.Renviron (collapsing any duplicates to
# a single line) and report the change.
renviron_set <- function(name, value, path = "~/.Renviron") {
  path <- path.expand(path)
  line <- paste0(name, "='", value, "'")
  existing <- if (file.exists(path)) readLines(path, warn = FALSE) else character()
  hit <- which(grepl(paste0("^\\s*", name, "\\s*="), existing))
  updating <- length(hit) > 0
  if (updating) {
    existing[hit[1]] <- line
    extras <- hit[-1]
    if (length(extras)) existing <- existing[-extras]
  } else {
    existing <- c(existing, line)
  }
  writeLines(existing, path)
  message(if (updating) "Replaced existing " else "Added ", name, " in ", path,
          " (available in new R sessions).")
  invisible(path)
}
