# Connection object and default-connection resolution.
#
# A seatable_connection is the unit of configuration. It stores the *name* of
# the environment variable holding the API token (never the token value), so a
# connection object is safe to print, share and inspect. The token is resolved
# lazily via seatable_token() at call time.

# Package-level registry for the "current" default connection.
.seatabler <- new.env(parent = emptyenv())

#' Create a connection to a SeaTable server
#'
#' @description A `seatable_connection` captures everything needed to reach a
#'   particular SeaTable server: its URL, the environment variable holding your
#'   API token, and (optionally) the workspace id and cache directory. It is the
#'   single place server configuration lives, so downstream functions and
#'   wrapper packages can bind one connection rather than passing
#'   URL/token/workspace arguments around.
#'
#' @details The token itself is never stored in the object — only the name of
#'   the environment variable that holds it (`token_envvar`). This keeps the
#'   object safe to print and share, and means the token is always read fresh.
#'   Resolve it with [seatable_token()].
#'
#' @param url Base URL of the SeaTable server (e.g.
#'   `"https://cloud.seatable.io/"`). Required — there is no default server.
#' @param token_envvar Name of the environment variable holding the API token.
#'   Defaults to the `seatabler.token_envvar` option, or `"SEATABLE_TOKEN"`.
#' @param workspace_id Optional workspace id (character or numeric). When `NULL`
#'   it is discovered from the base name where possible.
#' @param cachedir Optional per-connection cache directory. When `NULL` the
#'   `seatabler.cachedir` option is used.
#' @param name Optional short human-readable label for the connection.
#'
#' @return An object of class `seatable_connection`.
#' @export
#' @examples
#' con <- seatable_connection(
#'   url = "https://cloud.seatable.io/",
#'   token_envvar = "BANCTABLE_TOKEN",
#'   workspace_id = "57832")
#' con
seatable_connection <- function(url,
                                token_envvar = getOption("seatabler.token_envvar",
                                                         "SEATABLE_TOKEN"),
                                workspace_id = NULL,
                                cachedir = getOption("seatabler.cachedir", NULL),
                                name = NULL) {
  if (missing(url) || !is.character(url) || length(url) != 1 || !nzchar(url))
    stop("`url` must be a single non-empty string naming the SeaTable server.")
  checkmate::assert_string(token_envvar, min.chars = 1)
  # normalise to a single trailing slash
  url <- sub("/*$", "/", url)
  structure(
    list(
      url = url,
      token_envvar = token_envvar,
      workspace_id = if (is.null(workspace_id)) NULL else as.character(workspace_id),
      cachedir = cachedir,
      name = name
    ),
    class = "seatable_connection"
  )
}

#' @export
#' @rdname seatable_connection
#' @param x An object to test / print.
is_seatable_connection <- function(x) inherits(x, "seatable_connection")

#' @export
print.seatable_connection <- function(x, ...) {
  tok <- Sys.getenv(x$token_envvar, unset = NA_character_)
  tokstate <- if (is.na(tok) || !nzchar(tok)) "not set" else "set"
  cat("<seatable_connection>",
      if (!is.null(x$name)) paste0(" ", x$name) else "", "\n", sep = "")
  cat("  url:          ", x$url, "\n", sep = "")
  cat("  token_envvar: ", x$token_envvar, " (", tokstate, ")\n", sep = "")
  cat("  workspace_id: ", if (is.null(x$workspace_id)) "<discover>" else x$workspace_id,
      "\n", sep = "")
  if (!is.null(x$cachedir))
    cat("  cachedir:     ", x$cachedir, "\n", sep = "")
  invisible(x)
}

#' Resolve the API token for a connection
#'
#' @param con A [seatable_connection].
#' @param error Whether to error (default) or return `NA` when the token
#'   environment variable is unset.
#' @return The token string, or `NA_character_` when unset and `error = FALSE`.
#' @export
seatable_token <- function(con = default_connection(), error = TRUE) {
  stopifnot(is_seatable_connection(con))
  tok <- Sys.getenv(con$token_envvar, unset = NA_character_)
  if (is.na(tok) || !nzchar(tok)) {
    if (error)
      stop("No token found in environment variable `", con$token_envvar, "`.\n",
           "Set it (e.g. in ~/.Renviron), or use seatable_set_token() to obtain one.")
    return(NA_character_)
  }
  tok
}

#' The current default connection
#'
#' @description Returns the connection registered with
#'   [set_default_connection()], or one constructed from the `seatabler.url`,
#'   `seatabler.token_envvar` and `seatabler.workspace_id` options. Errors with
#'   guidance if no server URL is available.
#'
#'   Generic `seatable_*` functions default their `con` argument to this, so an
#'   interactive user can set a default once and then omit `con`. Wrapper
#'   packages instead pass an explicit connection so their end users never need
#'   to configure anything.
#'
#' @return A [seatable_connection].
#' @export
default_connection <- function() {
  con <- .seatabler$current
  if (is_seatable_connection(con))
    return(con)
  url <- getOption("seatabler.url", NULL)
  if (is.null(url))
    stop("No default seatable connection set.\n",
         "Either pass `con = seatable_connection(...)`, call ",
         "set_default_connection(), or set options(seatabler.url = ...).")
  seatable_connection(url = url)
}

#' Set (or clear) the default connection
#'
#' @param con A [seatable_connection], or `NULL` to clear the default.
#' @return The previous default connection, invisibly (or `NULL`).
#' @export
set_default_connection <- function(con) {
  old <- .seatabler$current
  if (is.null(con)) {
    if (exists("current", envir = .seatabler, inherits = FALSE))
      rm("current", envir = .seatabler)
  } else {
    stopifnot(is_seatable_connection(con))
    .seatabler$current <- con
  }
  invisible(old)
}

#' Evaluate an expression with a temporary default connection
#'
#' @param con A [seatable_connection] to use as the default for the duration of
#'   `expr`.
#' @param expr Expression to evaluate.
#' @return The value of `expr`.
#' @export
#' @examples
#' \dontrun{
#' with_connection(seatable_connection("https://cloud.seatable.io/"), {
#'   seatable_query("SELECT * FROM banc_meta")
#' })
#' }
with_connection <- function(con, expr) {
  stopifnot(is_seatable_connection(con))
  old <- set_default_connection(con)
  on.exit(set_default_connection(old))
  force(expr)
}

# Internal: accept a connection, or NULL to mean the current default.
as_connection <- function(con = NULL) {
  if (is.null(con)) return(default_connection())
  if (!is_seatable_connection(con))
    stop("`con` must be a seatable_connection (see ?seatable_connection).")
  con
}
