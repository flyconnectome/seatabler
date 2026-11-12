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

test_that("st_rbind_pages keeps integer64 values exact across pages", {
  big <- bit64::as.integer64(c("9007199254740993", "9007199254741000"))
  p64 <- data.frame(id = 1:2, n = big)
  pdbl <- data.frame(id = 3:4, n = c(5, NA))
  plgl <- data.frame(id = 5L, n = NA)

  # plain rbind() corrupts these when a double page comes first
  out <- seatabler:::st_rbind_pages(list(pdbl, p64, plgl))
  expect_true(bit64::is.integer64(out$n))
  expect_equal(as.character(out$n),
               c("5", NA, "9007199254740993", "9007199254741000", NA))
  expect_equal(out$id, c(3:4, 1:2, 5L))

  out <- seatabler:::st_rbind_pages(list(p64, pdbl))
  expect_true(bit64::is.integer64(out$n))
  expect_equal(as.character(out$n),
               c("9007199254740993", "9007199254741000", "5", NA))
})

test_that("st_rbind_pages falls back to double or character when it must", {
  p64 <- data.frame(n = bit64::as.integer64(c("12", "34")))
  out <- seatabler:::st_rbind_pages(list(data.frame(n = 0.5), p64))
  expect_type(out$n, "double")
  expect_false(bit64::is.integer64(out$n))
  expect_equal(out$n, c(0.5, 12, 34))

  big <- data.frame(n = bit64::as.integer64("9007199254740993"))
  out <- seatabler:::st_rbind_pages(list(data.frame(n = "x"), big))
  expect_equal(out$n, c("x", "9007199254740993"))
})

test_that("st_rbind_pages leaves pages that already agree alone", {
  a <- data.frame(n = c(1, 2), s = c("a", "b"))
  b <- data.frame(n = 3, s = "c")
  expect_identical(seatabler:::st_rbind_pages(list(a, b)), rbind(a, b))
})
