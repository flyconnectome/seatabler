# Writing rows to SeaTable: update existing rows and append new ones.
#
# Ported and merged from fafbseg's flytable_update_rows / flytable_append_rows
# (the maintained multi-select handling) and bancr's banctable_append_rows (the
# big-data / archived-rows REST path, which the SDK's batch_append_rows cannot
# reach). The payload builders are generic SeaTable operations -- no CAVE /
# neuroglancer / cloudvolume -- so they belong in this server-agnostic core.

#' Update or append rows in a SeaTable table
#'
#' @description `seatable_update_rows` updates existing rows (matched by their
#'   `_id`/`row_id`), returning `TRUE` on success. `seatable_append_rows` adds
#'   new rows, optionally straight into big data storage.
#'
#' @details SeaTable keeps a unique `_id` for every row, returned by
#'   [seatable_query()]. To update, keep that column (named `_id` or `row_id`)
#'   in `df`; to append you do not need it (and are warned if you supply one).
#'   Writes are chunked at `chunksize` rows because the API caps a single call
#'   at 1000.
#'
#'   **Multiple-select columns** need care: SeaTable expects a genuine list of
#'   option names per cell, and silently invents a new option from any bare
#'   string it is handed instead. Any column SeaTable reports as
#'   `"multiple-select"` is auto-detected and routed through a list-per-cell
#'   path; pass `multi_select_cols` to override detection. A scalar cell
#'   (`"AB"`, or comma-joined `"AB,CD"`) is accepted as shorthand and split on
#'   commas — symmetric with how such a cell reads back — or supply a
#'   list-column directly (`I(list(c("AB", "CD")))`), which also lets you write
#'   an option name that itself contains a comma. Every resulting value is
#'   checked against the column's existing vocabulary and rejected unless it is
#'   already an option; see `allow_new_options` and [seatable_add_select_options()].
#'
#'   **Big data** (`bigdata = TRUE`, append only): rows go through the
#'   `add-archived-rows` REST endpoint straight into archived storage, rather
#'   than the ordinary grid via the SDK. This is for bulk loads that would
#'   exceed the base's grid row cap; the base must have big data enabled or the
#'   gateway returns an error. Big data is an append *destination*, not a
#'   property of the table (a table can hold both grid and archived rows) — see
#'   [seatable_archive_rows()].
#'
#' @param df A data.frame of rows to write. For updates it must carry an `_id`
#'   or `row_id` column identifying each remote row.
#' @param table Name of the table.
#' @param base Optional base name or `Base` object; discovered from `table` when
#'   `NULL`.
#' @param con A [seatable_connection].
#' @param append_allowed For `seatable_update_rows`, whether rows whose id is
#'   missing may be appended as new rows rather than raising an error.
#' @param chunksize Split large requests into calls of at most this many rows.
#' @param multi_select_cols Column names to treat as multiple-select
#'   (list-per-cell). The default `NULL` auto-detects them from column metadata.
#' @param allow_new_options When a multiple-select value is not already an
#'   option for its column, whether to add it automatically (via
#'   [seatable_add_select_options()]) rather than erroring.
#'
#' @return Logical, invisibly: `TRUE` on success. Failures normally abort with
#'   the SeaTable error message.
#' @seealso [seatable_query()] to read rows back, [seatable_archive_rows()] to
#'   move rows into and out of big data storage.
#' @export
#' @examples
#' \dontrun{
#' rows <- seatable_query("SELECT _id, name FROM neurons LIMIT 2", con = con)
#' rows$name <- toupper(rows$name)
#' seatable_update_rows(rows, "neurons", con = con)
#'
#' seatable_append_rows(data.frame(name = "new cell"), "neurons", con = con)
#' }
seatable_update_rows <- function(df, table, base = NULL,
                                 con = default_connection(),
                                 append_allowed = TRUE, chunksize = 1000L,
                                 multi_select_cols = NULL,
                                 allow_new_options = FALSE) {
  con <- as_connection(con)
  if (is.null(base) || is.character(base))
    base <- seatable_base(base_name = base, table = table, con = con)
  df <- as.data.frame(df)
  nx <- nrow(df)
  if (!isTRUE(nx > 0)) {
    warning("No rows to update in `df`!")
    return(invisible(TRUE))
  }
  mscols <- st_resolve_multi_select_cols(df, table, base, con, multi_select_cols)
  df <- df2seatable(df, append = ifelse(append_allowed, NA, FALSE),
                    multi_select_cols = mscols)
  if (length(mscols) > 0)
    df <- st_check_multi_select_values(df, table, base, con, mscols,
                                       allow_new_options = allow_new_options)

  newrows <- is.na(df[["row_id"]])
  if (any(newrows)) {
    # append rather than update the rows that have no id
    seatable_append_rows(df[newrows, , drop = FALSE], table = table, base = base,
                         con = con, chunksize = chunksize,
                         multi_select_cols = mscols,
                         allow_new_options = allow_new_options)
    df <- df[!newrows, , drop = FALSE]
    nx <- nrow(df)
  }
  if (!isTRUE(nx > 0)) return(invisible(TRUE))

  if (nx > chunksize) {
    chunks <- st_chunks(df, chunksize)
    oks <- st_chunk_apply(chunks, function(ch)
      seatable_update_rows(ch, table = table, base = base, con = con,
                           chunksize = Inf, append_allowed = FALSE,
                           multi_select_cols = mscols,
                           allow_new_options = allow_new_options))
    return(invisible(all(oks)))
  }

  pyl <- df2updatepayload(df, multi_select_cols = mscols)
  res <- base$batch_update_rows(table_name = table, rows_data = pyl)
  invisible(isTRUE(all.equal(res, list(success = TRUE))))
}

#' @rdname seatable_update_rows
#' @param bigdata For `seatable_append_rows`, whether to write straight into big
#'   data (archived) storage via REST rather than the ordinary grid.
#' @export
seatable_append_rows <- function(df, table, base = NULL,
                                 con = default_connection(), bigdata = FALSE,
                                 chunksize = 1000L, multi_select_cols = NULL,
                                 allow_new_options = FALSE) {
  con <- as_connection(con)
  if (is.null(base) || is.character(base))
    base <- seatable_base(base_name = base, table = table, con = con)
  df <- as.data.frame(df)
  nx <- nrow(df)
  if (!isTRUE(nx > 0)) {
    warning("No rows to append in `df`!")
    return(invisible(TRUE))
  }
  mscols <- st_resolve_multi_select_cols(df, table, base, con, multi_select_cols)
  df <- df2seatable(df, append = TRUE, multi_select_cols = mscols)
  if (length(mscols) > 0)
    df <- st_check_multi_select_values(df, table, base, con, mscols,
                                       allow_new_options = allow_new_options)

  if (nx > chunksize) {
    chunks <- st_chunks(df, chunksize)
    oks <- st_chunk_apply(chunks, function(ch)
      seatable_append_rows(ch, table = table, base = base, con = con,
                           bigdata = bigdata, chunksize = Inf,
                           multi_select_cols = mscols,
                           allow_new_options = allow_new_options))
    return(invisible(all(oks)))
  }

  pyl <- df2appendpayload(df, multi_select_cols = mscols)
  if (!isTRUE(bigdata)) {
    res <- base$batch_append_rows(table_name = table, rows_data = pyl)
    return(invisible(isTRUE(all.equal(res[["inserted_row_count"]], nx))))
  }

  # Big data backend: the SDK cannot reach it, so post to the API gateway.
  rows <- reticulate::py_to_r(pyl)
  if (length(mscols) > 0)
    rows <- lapply(rows, function(r) {
      for (cc in intersect(names(r), mscols)) r[[cc]] <- I(as.character(r[[cc]]))
      r
    })
  res <- tryCatch(
    seatable_base_rest("add-archived-rows/", base = base, table = table,
                       con = con, method = "POST",
                       body = list(table_name = table, rows = rows)),
    error = function(e) stop(
      "Failed to append rows to big data storage: ", conditionMessage(e),
      "\nDoes this base have big data enabled? (bigdata = TRUE writes to the ",
      "archived backend; use bigdata = FALSE for the ordinary grid.)",
      call. = FALSE))
  invisible(isTRUE(res$success))
}

# private: convert a data.frame into the shape Base.batch_update_rows wants.
# via_json (or any multi-select column) forces per-row JSON assembly: slower on
# huge inputs but the only way a multi-select cell serialises as a real JSON
# array rather than a bare scalar (which SeaTable reads as "create a new
# option").
df2updatepayload <- function(x, via_json = FALSE, multi_select_cols = character(0)) {
  if (via_json || length(multi_select_cols) > 0) {
    othercols <- setdiff(colnames(x), "row_id")
    updates <- lapply(seq_len(nrow(x)), function(i) {
      row <- stats::setNames(lapply(othercols, function(col) {
        val <- x[[col]][[i]]
        # I() keeps a length-1 (or length-0) multi-select value as a JSON array
        # rather than an auto-unboxed scalar
        if (col %in% multi_select_cols) I(as.character(val)) else val
      }), othercols)
      list(row_id = x[["row_id"]][i], row = row)
    })
    js <- jsonlite::toJSON(updates, auto_unbox = TRUE, na = "null")
    pyjson <- reticulate::import("json")
    return(reticulate::py_call(pyjson$loads, js))
  }
  # fast path: pandas data.frame -> python list of {row_id, row}
  pdf <- reticulate::r_to_py(x)
  pyfun <- df2updatepayload_py()
  reticulate::py_call(pyfun$pdf2list, pdf)
}

# a memoised builder returning a python helper (saves a few ms per call)
df2updatepayload_py <- memoise::memoise(function() {
  reticulate::py_run_string(local = TRUE, paste0(
    "import pandas\n",
    "def pdf2list(df):\n",
    "  ids = df.row_id.values\n",
    "  data = df.drop('row_id', axis=1).to_dict(orient='records')\n",
    "  payload = [{'row_id': i, 'row': d} for i, d in zip(ids, data)]\n",
    "  return payload\n"))
})

# private: convert a data.frame into the shape Base.batch_append_rows wants.
df2appendpayload <- function(x, multi_select_cols = character(0)) {
  for (col in colnames(x)) {
    if (col %in% multi_select_cols) next
    # drop all-NA columns: SeaTable can choke on them and they add nothing
    if (isTRUE(all(is.na(x[[col]])))) x[[col]] <- NULL
  }
  if (length(multi_select_cols) > 0 && any(multi_select_cols %in% colnames(x))) {
    cols <- colnames(x)
    records <- lapply(seq_len(nrow(x)), function(i) {
      stats::setNames(lapply(cols, function(col) {
        val <- x[[col]][[i]]
        if (col %in% multi_select_cols) I(as.character(val)) else val
      }), cols)
    })
    js <- jsonlite::toJSON(records, auto_unbox = TRUE, na = "null")
    pyjson <- reticulate::import("json")
    return(reticulate::py_call(pyjson$loads, js))
  }
  pyx <- reticulate::r_to_py(x)
  pyx$to_dict("records")
}

# private: prepare a data.frame for upload. append = NA means "append or update"
# (id kept if present); append = TRUE drops id columns; append = FALSE requires
# a row_id for every row.
df2seatable <- function(df, append = TRUE, multi_select_cols = character(0)) {
  stopifnot(is.data.frame(df))
  if (isTRUE(append)) {
    idcols <- intersect(colnames(df), c("_id", "row_id"))
    if (length(idcols) > 0) {
      if (!all(is.na(df[idcols])))
        warning("Dropping _id / row_id columns. Maybe you want to update ",
                "rather than append?")
      df <- df[setdiff(colnames(df), c("_id", "row_id"))]
    }
    if (any(c("_mtime", "_ctime") %in% colnames(df))) {
      warning("Dropping _mtime, _ctime columns. Maybe you want to update ",
              "rather than append?")
      df <- df[setdiff(colnames(df), c("_mtime", "_ctime"))]
    }
  } else {
    if ("_id" %in% colnames(df))
      colnames(df)[colnames(df) == "_id"] <- "row_id"
    if (!isTRUE("row_id" %in% colnames(df)))
      stop("Data frames for update must have a _id or row_id column")
    if (any(duplicated(df[["row_id"]])))
      stop("Duplicate row _ids present!")
    df[["row_id"]][!nzchar(df[["row_id"]])] <- NA
    if (isFALSE(append) && any(is.na(df[["row_id"]])))
      stop("missing row _ids!")
  }

  int64cols <- which(vapply(df, bit64::is.integer64, logical(1)))
  for (i in int64cols) df[[i]] <- as.character(df[[i]])

  multi_select_cols <- intersect(multi_select_cols, colnames(df))
  for (col in multi_select_cols)
    df[[col]] <- st_listify_multiselect_col(df[[col]], col)

  listcols <- which(vapply(df, is.list, logical(1)))
  listcols <- setdiff(listcols, match(multi_select_cols, colnames(df)))
  for (i in listcols) {
    if (!isTRUE(all(lengths(df[[i]]) == 1)))
      stop("List column :", colnames(df)[i], " cannot be vectorised!")
    df[[i]] <- unlist(df[[i]])
  }
  df
}

# normalise a multi-select column into a list-column of character vectors, one
# per row. A scalar cell is split on commas (shorthand, symmetric with how such
# a cell reads back); a list-column cell is taken verbatim (so an option name
# containing a comma can be written as I(list("AB,CD"))).
st_listify_multiselect_col <- function(x, colname) {
  if (is.list(x)) {
    lapply(x, function(v) {
      if (is.null(v) || (length(v) == 1 && isTRUE(is.na(v)))) character(0)
      else as.character(v)
    })
  } else {
    x <- as.character(x)
    lapply(x, function(v) {
      if (is.na(v) || !nzchar(v)) return(character(0))
      parts <- trimws(strsplit(v, ",", fixed = TRUE)[[1]])
      parts[nzchar(parts)]
    })
  }
}

# which columns of df should be treated as multi-select: an explicit
# multi_select_cols wins, else auto-detect from column metadata.
st_resolve_multi_select_cols <- function(df, table, base, con, multi_select_cols) {
  if (!is.null(multi_select_cols))
    return(intersect(multi_select_cols, colnames(df)))
  tidf <- seatable_columns(table, base = base, con = con)
  intersect(tidf$name[tidf$type == "multiple-select"], colnames(df))
}

# reject (or, with allow_new_options, add) multi-select values that are not
# already in the column's option vocabulary -- this is what stops a typo
# silently creating a bogus option. Expects df already through df2seatable().
st_check_multi_select_values <- function(df, table, base, con, multi_select_cols,
                                         allow_new_options = FALSE) {
  cur <- seatable_select_options(table, multi_select_cols, base = base, con = con)
  for (col in multi_select_cols) {
    vals <- unique(unlist(df[[col]], use.names = FALSE))
    missing <- setdiff(vals, cur[[col]])
    if (length(missing) == 0) next
    if (isTRUE(allow_new_options)) {
      seatable_add_select_options(table, col, missing, base = base, con = con)
      cur[[col]] <- c(cur[[col]], missing)
    } else {
      stop(
        "Column '", col, "' has no option", if (length(missing) > 1) "s" else "",
        " ", paste(sprintf("'%s'", missing), collapse = ", "), ". ",
        "Add ", if (length(missing) > 1) "them" else "it", " in the SeaTable ",
        "UI, or run:\n  seatable_add_select_options('", table, "', '", col,
        "', ", deparse(missing), ")\n",
        "Or pass allow_new_options = TRUE to add automatically.", call. = FALSE)
    }
  }
  df
}

#' Read and add options for a select column
#'
#' @description `seatable_select_options` returns the option names currently
#'   defined for one or more single- or multiple-select columns.
#'   `seatable_add_select_options` adds new options to a column's vocabulary.
#'
#' @param table Name of the table.
#' @param col For `seatable_select_options`, single- or multiple-select column
#'   name(s); `NULL` (the default) returns every such column. For
#'   `seatable_add_select_options`, a single column name.
#' @param base Optional base name or `Base` object; discovered from `table` when
#'   `NULL`.
#' @param con A [seatable_connection].
#'
#' @return For `seatable_select_options`, a named list of character vectors (one
#'   per column) of option names. For `seatable_add_select_options`, the
#'   SeaTable response, invisibly.
#' @export
#' @examples
#' \dontrun{
#' seatable_select_options("neurons", "status", con = con)
#' seatable_add_select_options("neurons", "status", "reviewed", con = con)
#' }
seatable_select_options <- function(table, col = NULL, base = NULL,
                                    con = default_connection()) {
  con <- as_connection(con)
  if (is.null(base) || is.character(base))
    base <- seatable_base(base_name = base, table = table, con = con)
  md <- base$get_metadata()
  tablenames <- vapply(md$tables, "[[", character(1), "name")
  if (!table %in% tablenames)
    stop("Table '", table, "' not found in this base.")
  cols <- md$tables[[which(table == tablenames)]]$columns
  colnames_ <- vapply(cols, "[[", character(1), "name")
  types <- vapply(cols, "[[", character(1), "type")
  sel <- colnames_[types %in% c("single-select", "multiple-select")]
  if (!is.null(col)) {
    missing <- setdiff(col, sel)
    if (length(missing) > 0)
      stop("Not (all) single/multiple-select columns in table '", table, "': ",
           paste(missing, collapse = ", "))
    sel <- col
  }
  stats::setNames(lapply(sel, function(cc) {
    dd <- cols[[match(cc, colnames_)]]$data
    if (is.null(dd) || is.null(dd$options)) character(0)
    else vapply(dd$options, "[[", character(1), "name")
  }), sel)
}

#' @rdname seatable_select_options
#' @param options Character vector of new option name(s) to add.
#' @export
seatable_add_select_options <- function(table, col, options, base = NULL,
                                        con = default_connection()) {
  con <- as_connection(con)
  if (is.null(base) || is.character(base))
    base <- seatable_base(base_name = base, table = table, con = con)
  stopifnot(is.character(col), length(col) == 1)
  options <- unique(as.character(options))
  optlist <- lapply(options, function(nm)
    list(name = nm, color = st_random_option_color(), textColor = "#FFFFFF"))
  invisible(base$add_column_options(table_name = table, column = col,
                                    options = optlist))
}

# a SeaTable-style random hex colour for a newly created option
st_random_option_color <- function() {
  sprintf("#%06X", sample.int(16777216L, 1L) - 1L)
}

# split a data.frame into a list of <= chunksize-row chunks
st_chunks <- function(df, chunksize) {
  nx <- nrow(df)
  nchunks <- ceiling(nx / chunksize)
  chunkids <- rep(seq_len(nchunks), rep(chunksize, nchunks))[seq_len(nx)]
  split(df, chunkids)
}

# apply FUN over chunks, with a progress bar when pbapply is available
st_chunk_apply <- function(chunks, FUN) {
  if (requireNamespace("pbapply", quietly = TRUE))
    pbapply::pbsapply(chunks, FUN)
  else vapply(chunks, FUN, logical(1))
}
