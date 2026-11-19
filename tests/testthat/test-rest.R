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

# ---- seatable_http_error --------------------------------------------------
# Built from fabricated httr2 responses, so no server is needed.

json_resp <- function(status, body)
  httr2::response(status_code = status,
                  headers = list(`Content-Type` = "application/json"),
                  body = charToRaw(body))

test_that("seatable_http_error prefers SeaTable's error_message field", {
  err <- seatabler:::seatable_http_error(
    json_resp(400L, '{"error_message":"bad column"}'), 400L)
  expect_match(err, "HTTP 400")
  expect_match(err, "bad column")
})

test_that("seatable_http_error falls back through error_msg and detail", {
  expect_match(
    seatabler:::seatable_http_error(json_resp(400L, '{"error_msg":"em"}'), 400L),
    "em")
  expect_match(
    seatabler:::seatable_http_error(json_resp(400L, '{"detail":"dt"}'), 400L),
    "dt")
  # none of the known fields: fall back to the raw body string
  expect_match(
    seatabler:::seatable_http_error(json_resp(400L, '{"x":1}'), 400L),
    "\\{.*x.*1.*\\}")
})

test_that("seatable_http_error annotates rate limits and 404s", {
  expect_match(
    seatabler:::seatable_http_error(json_resp(429L, '{"error_message":"slow"}'), 429L),
    "rate limit")
  expect_match(
    seatabler:::seatable_http_error(json_resp(404L, '{"error_message":"nope"}'), 404L),
    "endpoint path")
})

test_that("seatable_http_error abbreviates a non-JSON (HTML) body", {
  html <- httr2::response(
    status_code = 500L, headers = list(`Content-Type` = "text/html"),
    body = charToRaw("<html><head><title>Server Error</title></head></html>"))
  err <- seatabler:::seatable_http_error(html, 500L)
  expect_match(err, "HTTP 500")
  expect_match(err, "HTML page: Server Error")
})
