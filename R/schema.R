# Column schema mutation.
#
# Adding and removing columns from R, so that migration scripts can extend a
# base without anyone opening the SeaTable web UI. Ported from bancr's
# banctable_add_column / _add_columns / _delete_column.

#' Add columns to a SeaTable table
#'
#' @description `seatable_add_column()` inserts a single new column;
#'   `seatable_add_columns()` adds several at once from a data frame of names
#'   and types, skipping any that already exist. Together they let a migration
#'   script bring a table's schema up to date without touching the SeaTable web
#'   interface.
#'
#' @details `column_type` uses SeaTable's own vocabulary — most commonly
#'   `"text"`, `"long-text"`, `"number"`, `"date"`, `"checkbox"`,
#'   `"single-select"` or `"multiple-select"`; see
#'   <https://api.seatable.io/reference/insert-column-2> for the full list.
#'
#'   Options for a select column, and other type-specific settings, go in
#'   `column_data`, e.g. `column_data = list(options = list(list(name = "yes"),
#'   list(name = "no")))`.
#'
#' @param table Name of the table to add to.
#' @param column_name Name of the new column.
#' @param column_type SeaTable column type (see Details). Defaults to `"text"`.
#' @param base Optional base name or `Base` object; discovered from `table` when
#'   `NULL`.
#' @param con A [seatable_connection].
#' @param column_data Optional list of type-specific column settings, e.g. the
#'   `options` of a select column.
#' @param column_key Optional key of an existing column, to position the new
#'   column immediately after it.
#'
#' @return For `seatable_add_column()`, the new column's definition, invisibly.
#'   For `seatable_add_columns()`, the subset of `columns` that was actually
#'   added, invisibly.
#' @export
#' @examples
#' \dontrun{
#' seatable_add_column("neurons", "cell_type", con = con)
#' seatable_add_column("neurons", "n_synapses", "number", con = con)
#'
#' # Bring a table up to a target schema, adding only what is missing
#' seatable_add_columns("neurons",
#'   data.frame(name = c("side", "notes"), type = c("text", "long-text")),
#'   con = con)
#' }
seatable_add_column <- function(table, column_name, column_type = "text",
                                base = NULL, con = default_connection(),
                                column_data = NULL, column_key = NULL) {
  con <- as_connection(con)
  if (is.null(base) || is.character(base))
    base <- seatable_base(base_name = base, table = table, con = con)
  kwargs <- list(table_name = table, column_name = column_name,
                 column_type = seatable_column_type(column_type))
  if (!is.null(column_data)) kwargs$column_data <- column_data
  if (!is.null(column_key)) kwargs$column_key <- column_key
  invisible(do.call(base$insert_column, kwargs))
}

#' @rdname seatable_add_column
#' @param columns A data frame with `name` and `type` columns — the same shape
#'   [seatable_columns()] returns, so the schema of one table can be replayed
#'   onto another.
#' @param progress Whether to report each column as it is added.
#' @export
seatable_add_columns <- function(table, columns, base = NULL,
                                 con = default_connection(), progress = TRUE) {
  columns <- as.data.frame(columns)
  if (!all(c("name", "type") %in% colnames(columns)))
    stop("`columns` must have `name` and `type` columns.")
  con <- as_connection(con)
  if (is.null(base) || is.character(base))
    base <- seatable_base(base_name = base, table = table, con = con)
  existing <- seatable_columns(table, base = base, con = con)$name
  todo <- columns[!columns$name %in% existing, , drop = FALSE]
  if (nrow(todo) == 0L) {
    if (isTRUE(progress)) message("All columns are already present.")
    return(invisible(todo))
  }
  if (isTRUE(progress))
    message(sprintf("Adding %d column(s) to '%s'.", nrow(todo), table))
  for (i in seq_len(nrow(todo))) {
    if (isTRUE(progress))
      message(sprintf("  + %-40s [%s]", todo$name[i], todo$type[i]))
    seatable_add_column(table = table, column_name = todo$name[i],
                        column_type = todo$type[i], base = base, con = con)
  }
  invisible(todo)
}

#' Delete a column from a SeaTable table
#'
#' @description Removes a column and all the data in it. This cannot be undone,
#'   so `seatable_delete_column()` takes the internal column *key* rather than
#'   its name: looking the key up with
#'   `seatable_columns(table, include_key = TRUE)` is a deliberate speed bump.
#'
#' @param table Name of the table.
#' @param column_key Internal key of the column to delete (e.g. `"8blF"`), from
#'   `seatable_columns(table, include_key = TRUE)`.
#' @param base Optional base name or `Base` object; discovered from `table` when
#'   `NULL`.
#' @param con A [seatable_connection].
#'
#' @return The SeaTable response, invisibly.
#' @export
#' @examples
#' \dontrun{
#' cols <- seatable_columns("neurons", include_key = TRUE, con = con)
#' key <- cols$key[cols$name == "scratch"]
#' seatable_delete_column("neurons", key, con = con)
#' }
seatable_delete_column <- function(table, column_key, base = NULL,
                                   con = default_connection()) {
  con <- as_connection(con)
  if (is.null(base) || is.character(base))
    base <- seatable_base(base_name = base, table = table, con = con)
  invisible(base$delete_column(table_name = table, column_key = column_key))
}

# Turn a SeaTable column type string into the ColumnTypes enum member the SDK
# expects. ColumnTypes is a Python Enum, so calling it with a value resolves to
# the matching member (ColumnTypes("text") -> ColumnTypes.TEXT). The import must
# use convert = FALSE, or reticulate coerces the member back to its `.value`
# string on the way out and the SDK fails with
# "'str' object has no attribute 'value'".
seatable_column_type <- function(column_type) {
  if (inherits(column_type, "python.builtin.object")) return(column_type)
  type_str <- as.character(column_type)[1]
  constants <- reticulate::import("seatable_api.constants", delay_load = FALSE,
                                  convert = FALSE)
  tryCatch(constants$ColumnTypes(type_str), error = function(e)
    stop("Unknown SeaTable column type '", type_str, "'. Common types are ",
         "text, long-text, number, date, checkbox, single-select and ",
         "multiple-select; see ?seatable_add_column. Original error: ",
         conditionMessage(e), call. = FALSE))
}
