# Authentication / Python SDK bootstrap.
#
# seatabler talks to SeaTable via the official `seatable_api` Python package
# through reticulate. Python-environment *management* is deliberately out of
# scope (that belongs in a consumer such as fafbseg::simple_python). Here we only
# import the package and give install guidance if it is missing.

#' Check that the seatable_api Python package is available
#'
#' @description Imports the `seatable_api` Python module via reticulate, erroring
#'   with install guidance if it is unavailable. Memoised so the import cost is
#'   paid once per session.
#'
#' @return The imported `seatable_api` module.
#' @export
check_seatable <- local({
  memoised <- NULL
  function() {
    if (!is.null(memoised)) return(memoised)
    if (!requireNamespace("reticulate", quietly = TRUE))
      stop("The 'reticulate' package is required to use seatabler.")
    st <- tryCatch(
      reticulate::import("seatable_api"),
      error = function(e)
        stop(call. = FALSE,
             "Could not import the Python 'seatable_api' package.\n",
             "Install it into the Python environment reticulate is using, e.g.\n",
             "  reticulate::py_install('seatable_api')\n",
             "or, if you use fafbseg, fafbseg::simple_python(pkgs = 'seatable_api').")
    )
    memoised <<- st
    st
  }
})

#' Log in to a SeaTable server
#'
#' @param con A [seatable_connection].
#' @return A Python SeaTable `Account` object (reticulate-wrapped), invisibly.
#' @export
#' @examples
#' \dontrun{
#' con <- seatable_connection("https://cloud.seatable.io/", "BANCTABLE_TOKEN")
#' seatable_login(con)
#' }
seatable_login <- function(con = default_connection()) {
  con <- as_connection(con)
  st <- check_seatable()
  token <- seatable_token(con)  # errors if unset
  ac <- reticulate::py_call(st$Account, login_name = NULL, password = NULL,
                            server_url = con$url)
  ac$token <- token
  invisible(ac)
}

#' Obtain and display a SeaTable API token
#'
#' @description Uses your SeaTable user name and password to obtain a permanent
#'   user-level API token, then tells you how to store it in the connection's
#'   `token_envvar`. Unlike the fafbseg original, this does **not** silently
#'   append to `~/.Renviron`; it prints the line so you can decide where to keep
#'   it.
#'
#' @param user,pwd SeaTable user name (email) and password.
#' @param con A [seatable_connection].
#' @return The token string, invisibly.
#' @export
seatable_set_token <- function(user, pwd, con = default_connection()) {
  con <- as_connection(con)
  st <- check_seatable()
  ac <- reticulate::py_call(st$Account, login_name = user, password = pwd,
                            server_url = con$url)
  ac$auth()
  token <- ac$token
  do.call(Sys.setenv, structure(list(token), names = con$token_envvar))
  message("Obtained a token and set ", con$token_envvar, " for this session.\n",
          "To persist it, add this line to ~/.Renviron:\n",
          con$token_envvar, "='", token, "'")
  invisible(token)
}
