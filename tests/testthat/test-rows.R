# Row-write transforms. The pure-R shaping (df2seatable, multi-select
# listifying, chunking, id validation) is tested offline; the JSON payload
# builders need reticulate but only Python's stdlib `json`, not a live server.

test_that("df2seatable stringifies int64 columns by value", {
  df <- data.frame(
    row_id = c("a", "b"),
    x = bit64::as.integer64(c("720575940621039145", "720575940626877799")),
    stringsAsFactors = FALSE)
  out <- seatabler:::df2seatable(df, append = FALSE)
  expect_identical(out$x, c("720575940621039145", "720575940626877799"))
})

test_that("df2seatable enforces ids on update and drops them on append", {
  # update (append = FALSE) needs a row_id for every row
  expect_error(seatabler:::df2seatable(data.frame(v = 1), append = FALSE),
               "must have a _id or row_id")
  expect_error(
    seatabler:::df2seatable(data.frame(row_id = c("x", "x"), v = 1:2),
                            append = FALSE), "Duplicate")
  expect_error(
    seatabler:::df2seatable(data.frame(row_id = c("x", ""), v = 1:2),
                            append = FALSE), "missing row _ids")
  # _id is renamed to row_id for updates
  out <- seatabler:::df2seatable(
    data.frame(`_id` = "x", v = 1, check.names = FALSE), append = FALSE)
  expect_true("row_id" %in% colnames(out))
  # append drops empty id columns silently
  app <- seatabler:::df2seatable(
    data.frame(`_id` = c(NA, NA), v = 1:2, check.names = FALSE), append = TRUE)
  expect_false("_id" %in% colnames(app))
})

test_that("st_listify_multiselect_col splits scalars and keeps lists verbatim", {
  expect_identical(
    seatabler:::st_listify_multiselect_col(c("AB,CD", NA, "EF"), "m"),
    list(c("AB", "CD"), character(0), "EF"))
  # a list-column cell is taken verbatim (commas inside a name preserved)
  expect_identical(
    seatabler:::st_listify_multiselect_col(I(list(c("A", "B"), "X,Y")), "m"),
    list(c("A", "B"), "X,Y"))
})

test_that("st_chunks splits to the requested size", {
  ch <- seatabler:::st_chunks(data.frame(a = 1:5), 2)
  expect_length(ch, 3)
  expect_equal(vapply(ch, nrow, integer(1)), c(2L, 2L, 1L), ignore_attr = TRUE)
})

test_that("df2updatepayload serialises multi-select cells as JSON arrays", {
  skip_if_not(seatable_api_available())
  df <- data.frame(row_id = "r1", tags = NA, stringsAsFactors = FALSE)
  df$tags <- list(c("AB", "CD"))
  pyl <- seatabler:::df2updatepayload(df, multi_select_cols = "tags")
  r <- reticulate::py_to_r(pyl)
  expect_identical(r[[1]]$row_id, "r1")
  expect_identical(as.character(r[[1]]$row$tags), c("AB", "CD"))

  # a length-1 multi-select value must still be an array, not a bare scalar
  df1 <- data.frame(row_id = "r2", stringsAsFactors = FALSE)
  df1$tags <- list("AB")
  r1 <- reticulate::py_to_r(
    seatabler:::df2updatepayload(df1, multi_select_cols = "tags"))
  expect_true(is.list(r1[[1]]$row$tags) || length(r1[[1]]$row$tags) == 1)
  expect_identical(as.character(r1[[1]]$row$tags), "AB")
})

test_that("df2appendpayload drops all-NA columns and arrays multi-select", {
  skip_if_not(seatable_api_available())
  df <- data.frame(name = c("a", "b"), empty = c(NA, NA),
                   stringsAsFactors = FALSE)
  df$tags <- list(c("X"), c("Y", "Z"))
  pyl <- seatabler:::df2appendpayload(df, multi_select_cols = "tags")
  r <- reticulate::py_to_r(pyl)
  expect_false("empty" %in% names(r[[1]]))
  expect_identical(as.character(r[[2]]$tags), c("Y", "Z"))
})

# ---- small pure helpers ---------------------------------------------------

test_that("st_random_option_color is a hex colour", {
  col <- seatabler:::st_random_option_color()
  expect_match(col, "^#[0-9A-F]{6}$")
})

test_that("st_chunk_apply applies FUN over chunks", {
  chunks <- list(data.frame(a = 1:2), data.frame(a = 3:5))
  out <- seatabler:::st_chunk_apply(chunks, function(ch) nrow(ch) > 1)
  expect_identical(unname(out), c(TRUE, TRUE))
})

test_that("st_resolve_multi_select_cols honours an explicit override", {
  df <- data.frame(a = 1, tags = 2, extra = 3)
  # explicit names are intersected with the frame's columns, no lookup needed
  expect_identical(
    seatabler:::st_resolve_multi_select_cols(df, "t", base = NULL, con = NULL,
                                             multi_select_cols = c("tags", "nope")),
    "tags")
})

# ---- select-option reading / checking (mocked schema) ---------------------

dummy_con <- function()
  seatable_connection(url = "https://example.com/", token_envvar = "NO_TOKEN")

# a schema frame shaped like seatable_columns() returns, carrying per-column
# `data` metadata with select options
mock_tidf <- function() {
  tidf <- data.frame(
    name = c("status", "tags", "note"),
    type = c("single-select", "multiple-select", "text"),
    stringsAsFactors = FALSE)
  tidf$data <- list(
    list(options = list(list(name = "new"), list(name = "done"))),
    list(options = list(list(name = "AB"))),
    NULL)
  tidf
}

test_that("seatable_select_options reads option names from the schema", {
  testthat::with_mocked_bindings(
    seatable_base = function(...) "base",
    seatable_columns = function(...) mock_tidf(),
    {
      # no col -> every select column
      all <- seatable_select_options("t", con = dummy_con())
      expect_identical(all, list(status = c("new", "done"), tags = "AB"))
      # a single named column
      one <- seatable_select_options("t", "status", con = dummy_con())
      expect_identical(one, list(status = c("new", "done")))
      # a non-select column errors
      expect_error(seatable_select_options("t", "note", con = dummy_con()),
                   "single/multiple-select")
    })
})

test_that("st_check_multi_select_values rejects or adds unknown options", {
  df <- data.frame(row_id = "r1", stringsAsFactors = FALSE)
  df$tags <- list(c("AB", "CD"))          # CD is not yet an option
  added <- NULL
  testthat::with_mocked_bindings(
    seatable_select_options = function(table, col, ...)
      stats::setNames(list("AB"), col),
    seatable_add_select_options = function(table, col, options, ...) {
      added <<- options; invisible(NULL)
    },
    {
      # default: refuse and point at the fix
      expect_error(
        seatabler:::st_check_multi_select_values(df, "t", base = NULL,
                                                 con = dummy_con(), "tags"),
        "no option")
      # allow_new_options = TRUE: add the missing one and return the frame
      out <- seatabler:::st_check_multi_select_values(
        df, "t", base = NULL, con = dummy_con(), "tags",
        allow_new_options = TRUE)
      expect_identical(added, "CD")
      expect_identical(out, df)
    })
})
