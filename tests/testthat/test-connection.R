# Pure connection-object tests (no network / no Python).

test_that("seatable_connection constructs and validates", {
  con <- seatable_connection("https://cloud.seatable.io", token_envvar = "MY_TOK",
                             workspace_id = 57832, name = "banc")
  expect_true(is_seatable_connection(con))
  expect_equal(con$url, "https://cloud.seatable.io/")   # trailing slash added
  expect_equal(con$token_envvar, "MY_TOK")
  expect_identical(con$workspace_id, "57832")           # coerced to character
  expect_error(seatable_connection(""), "non-empty")
  expect_error(seatable_connection(), "url")
})

test_that("seatable_token reads the named env var", {
  con <- seatable_connection("https://x/", token_envvar = "SEATABLER_TEST_TOK")
  withr::with_envvar(c(SEATABLER_TEST_TOK = ""), {
    expect_error(seatable_token(con), "No token")
    expect_true(is.na(seatable_token(con, error = FALSE)))
  })
  withr::with_envvar(c(SEATABLER_TEST_TOK = "abc123"), {
    expect_equal(seatable_token(con), "abc123")
  })
})

test_that("seatable_token prefers an embedded token over the env var", {
  con <- seatable_connection("https://x/", token = "literal-tok",
                             token_envvar = "SEATABLER_TEST_TOK")
  withr::with_envvar(c(SEATABLER_TEST_TOK = "envtok"), {
    expect_equal(seatable_token(con), "literal-tok")
  })
})

test_that("default connection: registry, options fallback, error", {
  old <- set_default_connection(NULL)
  on.exit(set_default_connection(old))

  withr::with_options(list(seatabler.url = NULL), {
    expect_error(default_connection(), "No default")
  })
  withr::with_options(list(seatabler.url = "https://from-option/"), {
    con <- default_connection()
    expect_equal(con$url, "https://from-option/")
  })

  reg <- seatable_connection("https://registered/")
  prev <- set_default_connection(reg)
  expect_equal(default_connection()$url, "https://registered/")
  # registry beats options
  withr::with_options(list(seatabler.url = "https://from-option/"), {
    expect_equal(default_connection()$url, "https://registered/")
  })
  set_default_connection(prev)
})

test_that("with_connection scopes the default and restores it", {
  old <- set_default_connection(NULL)
  on.exit(set_default_connection(old))
  a <- seatable_connection("https://a/")
  b <- seatable_connection("https://b/")
  set_default_connection(a)
  with_connection(b, {
    expect_equal(default_connection()$url, "https://b/")
  })
  expect_equal(default_connection()$url, "https://a/")
})

test_that("print method redacts and reports token state", {
  con <- seatable_connection("https://x/", token_envvar = "SEATABLER_PRINT_TOK")
  withr::with_envvar(c(SEATABLER_PRINT_TOK = ""), {
    out <- paste(capture.output(print(con)), collapse = "\n")
  })
  expect_match(out, "seatable_connection")
  expect_match(out, "not set")
  expect_false(grepl("abc", out))
})

test_that("print redacts an embedded token", {
  con <- seatable_connection("https://x/", token = "supersecret")
  out <- paste(capture.output(print(con)), collapse = "\n")
  expect_false(grepl("supersecret", out))
  expect_match(out, "hidden")
})

test_that("renviron_set replaces, de-duplicates and appends", {
  f <- withr::local_tempfile()
  writeLines(c("FOO=1", "MYTOK='old'", "BAR=2", "MYTOK='dup'"), f)
  suppressMessages(seatabler:::renviron_set("MYTOK", "new", path = f))
  ll <- readLines(f)
  expect_equal(sum(grepl("^MYTOK=", ll)), 1L)          # duplicates collapsed
  expect_true(any(ll == "MYTOK='new'"))                 # value replaced
  expect_true(all(c("FOO=1", "BAR=2") %in% ll))         # others untouched

  g <- withr::local_tempfile()
  writeLines("A=1", g)
  suppressMessages(seatabler:::renviron_set("B", "2", path = g))
  expect_true(any(readLines(g) == "B='2'"))             # appended when absent
})
