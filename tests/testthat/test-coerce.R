tidf <- data.frame(
  name = c("id", "label", "tags"),
  type = c("number", "text", "multiple-select"),
  rtype = c("numeric", "character", "character"),
  stringsAsFactors = FALSE)

test_that("st_coerce_df comma-joins multi-valued cells and NAs empties", {
  df <- data.frame(id = 1:3, stringsAsFactors = FALSE)
  df$tags <- list(c("a", "b"), "c", character(0))
  out <- seatabler:::st_coerce_df(df, tidf = tidf, collapse = TRUE)
  expect_equal(out$tags, c("a,b", "c", NA))
  expect_type(out$tags, "character")
})

test_that("st_coerce_df honours a custom separator", {
  df <- data.frame(id = 1L, stringsAsFactors = FALSE)
  df$tags <- list(c("a", "b"))
  out <- seatabler:::st_coerce_df(df, tidf = tidf, collapse = "; ")
  expect_equal(out$tags, "a; b")
})

test_that("st_coerce_df keeps list-columns when collapse = FALSE", {
  df <- data.frame(id = 1:2, stringsAsFactors = FALSE)
  df$tags <- list(c("a", "b"), "c")
  expect_warning(
    out <- seatabler:::st_coerce_df(df, tidf = tidf, collapse = FALSE),
    "cannot be vectorised")
  expect_true(is.list(out$tags))
})

test_that("st_coerce_df treats a scalar NA multi-select cell as empty", {
  # pandas fills a multiple-select column with float NaN for missing cells when
  # only some rows in a batch have a value -- that must read as empty, not "NaN".
  df <- data.frame(id = 1:2, stringsAsFactors = FALSE)
  df$tags <- list(c("a", "b"), NA)
  out <- seatabler:::st_coerce_df(df, tidf = tidf, collapse = TRUE)
  expect_equal(out$tags, c("a,b", NA))

  # without the schema it cannot know `tags` is multi-select, so the scalar NA
  # is collapsed like any value and stringifies to a literal "NA" -- exactly the
  # bug the schema-aware path above prevents.
  out2 <- seatabler:::st_coerce_df(df, tidf = NULL, collapse = TRUE)
  expect_equal(out2$tags, c("a,b", "NA"))
})

test_that("st_coerce_df unlists an all-length-1 list column", {
  df <- data.frame(id = 1:3, stringsAsFactors = FALSE)
  df$tags <- list("a", "b", "c")
  out <- seatabler:::st_coerce_df(df, tidf = tidf, collapse = TRUE)
  expect_identical(out$tags, c("a", "b", "c"))
})

test_that("st_coerce_df maps length-0/1 columns to a char vector with NA", {
  df <- data.frame(id = 1:3, stringsAsFactors = FALSE)
  df$tags <- list("a", character(0), "c")
  out <- seatabler:::st_coerce_df(df, tidf = tidf, collapse = TRUE)
  expect_identical(out$tags, c("a", NA, "c"))
})

test_that("st_coerce_df leaves non-list columns untouched when types match", {
  df <- data.frame(id = 1:2, label = c("x", "y"), stringsAsFactors = FALSE)
  out <- seatabler:::st_coerce_df(df, tidf = tidf, collapse = TRUE)
  expect_identical(out$id, 1:2)
  expect_identical(out$label, c("x", "y"))
})

test_that("st_coerce_df applies SeaTable column types (fix_coltypes)", {
  # list_rows returns everything as strings; the schema restores R types
  df <- data.frame(n = c("1", "2", "3"), flag = c("True", "", "True"),
                   note = c("a", "b", "c"), stringsAsFactors = FALSE)
  tt <- data.frame(name = c("n", "flag", "note"),
                   type = c("number", "checkbox", "text"),
                   rtype = c("numeric", "logical", "character"),
                   stringsAsFactors = FALSE)
  out <- seatabler:::st_coerce_df(df, tidf = tt)
  expect_identical(out$n, c(1, 2, 3))
  expect_type(out$flag, "logical")
  expect_identical(out$note, c("a", "b", "c"))
})

test_that("st_coerce_df parses timestamp columns to POSIXt", {
  df <- data.frame(`_mtime` = c("2021-06-23T07:01:00+00:00",
                                "2022-01-12T09:30:00+00:00"),
                   check.names = FALSE, stringsAsFactors = FALSE)
  tt <- data.frame(name = "_mtime", type = "mtime", rtype = "POSIXct",
                   stringsAsFactors = FALSE)
  out <- seatabler:::st_coerce_df(df, tidf = tt)
  expect_s3_class(out$`_mtime`, "POSIXt")
  expect_false(anyNA(out$`_mtime`))
})

test_that("st_coerce_df is a no-op on a zero-column frame", {
  df <- data.frame()
  expect_identical(seatabler:::st_coerce_df(df), df)
})

test_that("st_coerce_df leaves columns absent from the schema alone", {
  # e.g. a COUNT(_id) result column not present in tidf
  df <- data.frame(`COUNT(_id)` = 42L, check.names = FALSE)
  out <- seatabler:::st_coerce_df(df, tidf = tidf)
  expect_identical(out[["COUNT(_id)"]], 42L)
})
