# Authentication / Python SDK bootstrap.
#
# seatabler talks to SeaTable via the official `seatable_api` Python package
# through reticulate. Python-environment *management* is deliberately out of
# scope (that belongs in a consumer such as fafbseg::simple_python). Here we only
# import the package and give install guidance if it is missing.

#' Import the seatable_api Python module
#'
#' @description Imports the `seatable_api` Python module via reticulate, on which
#'   every other seatabler function relies. seatabler does **not** manage Python
#'   environments itself; instead it declares the requirement and, on a failed
#'   import, tries in order: (1) a consumer-registered provisioner (see details),
#'   (2) an interactive `reticulate::py_install()` into the environment
#'   reticulate is already using, before finally erroring with guidance.
#'   Memoised, so the import cost is paid once per session.
#'
#' @details **Ecosystem integration without a dependency.** A package that
#'   manages its own Python environment (e.g. fafbseg, via `simple_python()`) can
#'   register a provisioner so seatabler installs `seatable_api` into *that*
#'   environment rather than guessing. Register a zero-argument function via the
#'   `seatabler.python_provisioner` option — typically in the consumer's
#'   `.onLoad()`:
#'
#'   \preformatted{
#'   # in fafbseg .onLoad():
#'   options(seatabler.python_provisioner = function()
#'     fafbseg::simple_python(pkgs = "seatable_api"))
#'   }
#'
#'   Because fafbseg depends on seatabler (not the other way round) it can set
#'   this hook, giving seatabler access to `simple_python` without seatabler
#'   depending on fafbseg. Standalone users need no hook — they get the
#'   interactive `py_install()` fallback, or can install `seatable_api`
#'   themselves.
#'
#' @return The imported `seatable_api` module.
#' @export
seatable_module <- local({
  memoised <- NULL
  function() {
    if (!is.null(memoised)) return(memoised)
    if (!requireNamespace("reticulate", quietly = TRUE))
      stop("The 'reticulate' package is required to use seatabler.")
    import_st <- function() tryCatch(reticulate::import("seatable_api"),
                                     error = function(e) NULL)
    st <- import_st()

    # 1. Consumer-registered provisioner (e.g. fafbseg's simple_python), so the
    #    package lands in whatever env that consumer manages.
    if (is.null(st)) {
      prov <- getOption("seatabler.python_provisioner")
      if (is.function(prov)) {
        try(prov(), silent = TRUE)
        st <- import_st()
      }
    }

    # 2. Interactive fallback: install into the env reticulate is already bound
    #    to. Only with consent, since it mutates the user's Python environment.
    if (is.null(st) && interactive()) {
      ans <- readline("Install the Python 'seatable_api' package now (y/n)? ")
      if (tolower(trimws(ans)) %in% c("y", "yes")) {
        try(reticulate::py_install("seatable_api"), silent = TRUE)
        st <- import_st()
      }
    }

    if (is.null(st))
      stop(call. = FALSE,
           "Could not import the Python 'seatable_api' package.\n",
           "Install it into the Python environment reticulate is using, e.g.\n",
           "  reticulate::py_install('seatable_api')\n",
           "or, if you use fafbseg, fafbseg::simple_python(pkgs = 'seatable_api').\n",
           "Packages that manage their own Python env can also register a ",
           "provisioner via options(seatabler.python_provisioner = ...); ",
           "see ?seatable_module.")
    memoised <<- st
    st
  }
})

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
