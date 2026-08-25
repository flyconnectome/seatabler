test_that(".onLoad sets the token_envvar default without clobbering", {
  # the package sets a default token env-var name on load
  expect_identical(getOption("seatabler.token_envvar"), "SEATABLE_TOKEN")
  # re-running .onLoad leaves an already-set option untouched
  withr::local_options(seatabler.token_envvar = "MY_TOKEN")
  seatabler:::.onLoad("lib", "seatabler")
  expect_identical(getOption("seatabler.token_envvar"), "MY_TOKEN")
})
