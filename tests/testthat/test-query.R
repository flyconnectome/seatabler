test_that("is_rate_limit spots throttling but not ordinary errors", {
  expect_true(seatabler:::is_rate_limit("HTTPError: 429 Client Error"))
  expect_true(seatabler:::is_rate_limit("Too Many Requests"))
  expect_true(seatabler:::is_rate_limit("api rate limit exceeded"))
  expect_false(seatabler:::is_rate_limit("KeyError: 'no such table'"))
  expect_false(seatabler:::is_rate_limit(character()))
})

test_that("depython_columns leaves native columns alone", {
  df <- data.frame(a = 1:3, b = letters[1:3], stringsAsFactors = FALSE)
  expect_identical(seatabler:::depython_columns(df), df)
  expect_identical(seatabler:::depython_columns(df[0, ]), df[0, ])
})

test_that("sql2fields reads the selected columns", {
  expect_equal(seatabler:::sql2fields("SELECT * FROM t"), "*")
  expect_equal(seatabler:::sql2fields("SELECT a, b FROM t"), c("a", "b"))
})
