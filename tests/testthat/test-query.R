test_that("is_rate_limit spots throttling but not ordinary errors", {
  expect_true(seatabler:::is_rate_limit("HTTPError: 429 Client Error"))
  expect_true(seatabler:::is_rate_limit("Too Many Requests"))
  expect_true(seatabler:::is_rate_limit("api rate limit exceeded"))
  expect_false(seatabler:::is_rate_limit("KeyError: 'no such table'"))
  expect_false(seatabler:::is_rate_limit(character()))
})

test_that("sql2fields reads the selected columns", {
  expect_equal(seatabler:::sql2fields("SELECT * FROM t"), "*")
  expect_equal(seatabler:::sql2fields("SELECT a, b FROM t"), c("a", "b"))
})
