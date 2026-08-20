# Non-SQL read paths: list_rows (the SDK's paginated row listing) and
# list_selected (a thin SQL builder over seatable_query). Both return the same
# post-processed data.frame that seatable_query does -- read-side coercion is
# delegated to nat.python::pandas2df, so there is no `collapse_lists` knob here
# (SeaTable list-cell flattening happens there, uniformly).

#' List rows from a SeaTable table
#'
#' @description Reads rows through SeaTable's `list_rows` API (rather than SQL),
#'   optionally restricted to a view and ordered by a column. Returns an R
#'   `data.frame`, or the raw pandas `DataFrame` when `python = TRUE`.
#'
#' @details The `list_rows` endpoint caps the number of rows per request, and
#'   that cap is server-configurable with no API to discover it, so a page
#'   coming back shorter than requested does **not** signal the end of the
#'   table -- only an empty page does. Rows are therefore fetched in chunks
#'   until an empty page (or `limit`) is reached, then concatenated once and
#'   coerced together, so multiple-select and other list columns flatten
#'   uniformly across chunks.
#'
#' @param table Name of the table.
#' @param base Optional base name or `Base` object; discovered from `table` when
#'   `NULL`.
#' @param con A [seatable_connection].
#' @param view_name Optional view limiting the rows/columns returned.
#' @param order_by Optional column name to order by.
#' @param desc Whether to sort descending (default ascending).
#' @param start Row offset to start from (0-based).
#' @param limit Maximum rows to return; the default `Inf` returns all rows.
#' @param python Whether to return the pandas `DataFrame` rather than an R
#'   `data.frame`.
#' @param chunksize Advanced: rows to request per call. The default `NULL`
#'   chooses a size from the column count (SeaTable allows roughly one million
#'   cells per request).
#'
#' @return An R `data.frame`, or a pandas `DataFrame` when `python = TRUE`.
#' @seealso [seatable_query()], [seatable_list_selected()]
#' @export
seatable_list_rows <- function(table, base = NULL, con = default_connection(),
                               view_name = NULL, order_by = NULL, desc = FALSE,
                               start = 0L, limit = Inf, python = FALSE,
                               chunksize = NULL) {
  con <- as_connection(con)
  if (is.null(base) || is.character(base))
    base <- seatable_base(base_name = base, table = table, con = con)
  colinfo <- seatable_columns(table, base = base, con = con)
  ncols <- max(length(colinfo$name), 1L)
  if (is.null(chunksize)) chunksize <- pmin(floor(1e6 / ncols), 50000L)

  pd <- reticulate::import("pandas")
  frames <- list()
  start <- as.integer(start)
  offset <- start
  repeat {
    fetched <- offset - start
    rowstofetch <- if (is.finite(limit)) pmin(limit - fetched, chunksize) else chunksize
    if (rowstofetch < 1) break
    lim <- if (is.finite(rowstofetch)) as.integer(rowstofetch) else NULL
    ll <- reticulate::py_call(base$list_rows, table_name = table,
                              view_name = view_name, order_by = order_by,
                              desc = desc, start = as.integer(offset),
                              limit = lim)
    reticulate::py_capture_output(pdd <- reticulate::py_call(pd$DataFrame, ll))
    n <- as.integer(reticulate::py_to_r(pdd$shape)[[1]])
    # An empty page is the only reliable end-of-table signal (see @details).
    if (n == 0) break
    frames[[length(frames) + 1]] <- pdd
    offset <- offset + n
  }

  if (length(frames) == 0) {
    empty <- stats::setNames(
      as.data.frame(replicate(length(colinfo$name), character(0),
                              simplify = FALSE), stringsAsFactors = FALSE),
      colinfo$name)
    return(if (python) reticulate::py_call(pd$DataFrame) else empty)
  }
  pdd <- if (length(frames) == 1) frames[[1]]
         else reticulate::py_call(pd$concat, frames, ignore_index = TRUE)
  if (python) return(pdd)

  df <- nat.python::pandas2df(pdd)
  toorder <- intersect(colinfo$name, colnames(df))
  df <- df[c(toorder, setdiff(colnames(df), toorder))]
  if (is.finite(limit) && nrow(df) > limit) df <- df[seq_len(limit), , drop = FALSE]
  df
}

#' Select rows from a SeaTable table by id
#'
#' @description Builds and runs a `SELECT ... WHERE <idfield> IN (...)` query
#'   for a set of ids -- a convenience over writing the SQL by hand. With no
#'   `ids` it returns the whole table.
#'
#' @details This is a generic id lookup: `ids` are matched against `idfield`
#'   verbatim, with no coercion. Consumer packages that key on a domain id (for
#'   example a flywire root id that must be resolved to its current value first)
#'   should do that resolution in their own wrapper before calling this.
#'   Whether values are quoted in the SQL is decided from `idfield`'s column
#'   type (numeric columns are left unquoted).
#'
#' @param ids Ids to look up, matched against `idfield`. `NULL` (the default)
#'   returns every row.
#' @param table Name of the table.
#' @param fields Columns to return: `"*"` (default) for all, a comma-separated
#'   string, or a character vector of column names (back-quoted for you).
#' @param idfield Column to match `ids` against. Required when `ids` is
#'   supplied.
#' @param base Optional base name or `Base` object; discovered from `table` when
#'   `NULL`.
#' @param con A [seatable_connection].
#' @param ... Passed to [seatable_query()] (e.g. `limit`, `python`).
#'
#' @return A data.frame of the selected rows and columns.
#' @seealso [seatable_query()], [seatable_list_rows()]
#' @export
seatable_list_selected <- function(ids = NULL, table, fields = "*",
                                   idfield = NULL, base = NULL,
                                   con = default_connection(), ...) {
  con <- as_connection(con)
  if (length(fields) > 1 ||
      (length(fields) == 1 && fields != "*" && !grepl("[,`]", fields)))
    fields <- paste0("`", fields, "`", collapse = ",")
  if (is.null(ids)) {
    sql <- sprintf("select %s from %s", fields, table)
  } else {
    if (is.null(idfield))
      stop("Supply `idfield`: the column to match `ids` against.")
    isnumber <- isTRUE(st_col_type(idfield, table, base = base, con = con) == "numeric")
    sql <- sprintf("select %s from %s where %s %s", fields, table, idfield,
                   ids2sqlin(ids, quote = !isnumber))
  }
  fq <- seatable_query(sql, con = con, base = base, ...)
  if (isTRUE(nrow(fq) > 0) && identical(fields, "*")) {
    cols <- seatable_columns(table, base = base, con = con)$name
    dplyr::select(fq, dplyr::all_of(intersect(cols, colnames(fq))),
                  dplyr::everything())
  } else fq
}

# private: an `IN (...)` clause from a vector of ids, quoted unless numeric.
ids2sqlin <- function(ids, quote = TRUE) {
  if (quote) ids <- shQuote(ids)
  sprintf("IN (%s)", paste(ids, collapse = ","))
}

# private: the rtype ("numeric", "character", ...) of one column.
st_col_type <- function(col, table, base = NULL, con = default_connection()) {
  tidf <- seatable_columns(table, base = base, con = con)
  tidf$rtype[match(col, tidf$name)]
}
