# SQL query with transparent pagination.
#
# Vertical slice ported from fafbseg::flytable_query, generalised to take a
# connection. The pagination logic is carried over verbatim (it was recently
# hardened for servers whose per-call SQL row cap is unknown). The pandas -> R
# conversion here is deliberately minimal; the richer column-type and
# multi-select handling is marked TODO(port) below and should come from
# fafbseg's flytable2df / pandas2df / fix_coltypes.

#' Run a SQL query against a SeaTable server
#'
#' @param sql A single SQL `SELECT` statement. The table name is parsed from the
#'   `FROM` clause.
#' @param con A [seatable_connection].
#' @param limit Maximum rows to return. The default fetches all rows,
#'   paginating as needed.
#' @param base Optional base name or `Base` object; discovered from the table
#'   name when `NULL`.
#' @param python If `TRUE`, return the raw pandas `DataFrame` instead of an R
#'   `data.frame`.
#' @param convert Passed to the SeaTable Python `query` call.
#' @param paginate Whether to page through large results automatically
#'   (default `TRUE`). SeaTable's SQL endpoint silently caps a single call at a
#'   server-specific maximum; pagination returns the full result.
#' @param chunksize Advanced: force `LIMIT`/`OFFSET` paging in fixed windows of
#'   this size. The default `NULL` auto-detects the server's per-call cap.
#' @return An R `data.frame` (or a pandas `DataFrame` when `python = TRUE`).
#' @export
#' @examples
#' \dontrun{
#' con <- seatable_connection("https://cloud.seatable.io/", "BANCTABLE_TOKEN",
#'                            workspace_id = "57832")
#' seatable_query("SELECT * FROM banc_meta", con = con)
#' }
seatable_query <- function(sql, con = default_connection(),
                           limit = 100000L, base = NULL, python = FALSE,
                           convert = TRUE, paginate = TRUE, chunksize = NULL) {
  con <- as_connection(con)
  checkmate::assert_character(sql, len = 1, pattern = "select", ignore.case = TRUE)
  res <- stringr::str_match(sql,
    stringr::regex("\\s+FROM\\s+[']{0,1}([^, ']+).*", ignore_case = TRUE))
  if (any(is.na(res)[, 2]))
    stop("Cannot identify a table name in your SQL statement.")
  table <- res[, 2]
  if (is.null(base)) {
    base <- try(seatable_base(table = table, con = con), silent = TRUE)
    if (inherits(base, "try-error"))
      stop("Inferred table '", table, "' from the SQL but could not connect to ",
           "a base containing it.")
  } else if (is.character(base)) {
    base <- seatable_base(base_name = base, con = con)
  }

  has_own_limit <- isTRUE(grepl("\\s+limit\\s+\\d+", sql, ignore.case = TRUE))
  if (!is.finite(limit)) limit <- .Machine$integer.max
  colinfo <- if (python) NULL else seatable_columns(table, base, con = con)

  run_one <- function(sqltext) {
    pyout <- reticulate::py_capture_output(
      ll <- try(reticulate::py_call(base$query, sqltext, convert = convert),
                silent = TRUE))
    if (inherits(ll, "try-error")) {
      # TODO(port): fafbseg/bancr detect HTTP 429 rate-limits here and back off.
      warning(paste("No rows returned by seatable_query:", pyout, collapse = "\n"))
      return(NULL)
    }
    pd <- reticulate::import("pandas")
    reticulate::py_capture_output(pdd <- reticulate::py_call(pd$DataFrame, ll))
    if (python) return(pdd)
    df <- seatable_pandas2df(pdd)  # TODO(port): richer flytable2df/fix_coltypes
    fields <- sql2fields(sqltext)
    toorder <- if (length(fields) == 1 && fields == "*")
      intersect(colinfo$name, colnames(df)) else intersect(fields, colnames(df))
    df[c(toorder, setdiff(colnames(df), toorder))]
  }

  do_paginate <- isTRUE(paginate) && !python && !has_own_limit && is.finite(limit)
  if (!do_paginate) {
    sqltext <- if (!has_own_limit) paste(sql, "LIMIT", limit) else sql
    return(run_one(sqltext))
  }

  if (is.null(chunksize)) {
    guaranteed_cap <- 10000L
    page1 <- run_one(paste(sql, "LIMIT", limit, "OFFSET 0"))
    if (is.null(page1)) return(NULL)
    np1 <- nrow(page1)
    if (np1 >= limit || np1 < guaranteed_cap) return(page1)
    probe <- run_one(paste(sql, "LIMIT 1 OFFSET", np1))
    if (is.null(probe) || nrow(probe) == 0) return(page1)
    cap <- np1
    pages <- list(page1)
    offset <- np1
  } else {
    cap <- min(as.integer(chunksize), limit)
    pages <- list()
    offset <- 0L
  }

  repeat {
    remaining <- limit - offset
    if (remaining < 1) break
    ps <- min(cap, remaining)
    page <- run_one(paste(sql, "LIMIT", ps, "OFFSET", offset))
    if (is.null(page) || nrow(page) == 0) break
    pages[[length(pages) + 1]] <- page
    offset <- offset + nrow(page)
    if (nrow(page) < ps) break
  }
  if (length(pages) == 0) return(NULL)
  out <- if (length(pages) == 1) pages[[1]] else {
    tt <- try(do.call(rbind, pages), silent = TRUE)
    if (inherits(tt, "try-error")) tt <- dplyr::bind_rows(pages)
    tt
  }
  if (nrow(out) > limit) out <- out[seq_len(limit), , drop = FALSE]
  out
}

# Parse the selected field names from a SELECT statement ("*" or a vector).
sql2fields <- function(sql) {
  fieldstring <- sub("SELECT\\s+(.+)\\s+FROM\\s+.+", "\\1", sql, ignore.case = TRUE)
  if (nchar(sql) == nchar(fieldstring)) return(character())
  trimws(scan(text = fieldstring, sep = ",", what = "", quiet = TRUE))
}

# Minimal pandas DataFrame -> R data.frame conversion.
# TODO(port): replace with fafbseg's flytable2df + pandas2df + fix_coltypes so
# that column R-types, list/multi-select columns and NA handling match exactly.
seatable_pandas2df <- function(pdd) {
  df <- reticulate::py_to_r(pdd)
  if (!is.data.frame(df)) df <- as.data.frame(df, stringsAsFactors = FALSE)
  df
}
