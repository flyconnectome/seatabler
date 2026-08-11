test_that("abbreviate_body summarises an HTML error page", {
  html <- paste0("<!DOCTYPE html>\n<html lang='en'><head><title>SeaTable Cloud",
                 "</title></head><body>", strrep("x", 5000), "</body></html>")
  expect_equal(seatabler:::abbreviate_body(html), "<HTML page: SeaTable Cloud>")
})

test_that("abbreviate_body truncates long plain text", {
  out <- seatabler:::abbreviate_body(strrep("a", 1000))
  expect_lt(nchar(out), 350)
  expect_match(out, "truncated")
})

test_that("abbreviate_body handles an empty body", {
  expect_equal(seatabler:::abbreviate_body(""), "<empty response body>")
  expect_equal(seatabler:::abbreviate_body(character()), "<empty response body>")
})
