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
