# seatabler: a generic R client for SeaTable servers

seatabler provides a server-agnostic client for SeaTable databases. A
[`seatable_connection()`](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md)
captures a server URL, the environment variable holding your API token,
and an optional workspace; the generic `seatable_*` functions then
query, read, write and cache tables against any server.

There is no default server and no domain logic. Packages such as fafbseg
and bancr are expected to wrap these functions, binding their own
connection so their users need no configuration.

## Getting started


    con <- seatable_connection(
      url = "https://cloud.seatable.io/",
      token_envvar = "SEATABLE_TOKEN")
    seatable_query("SELECT * FROM my_table", con = con)

## See also

Useful links:

- <https://github.com/flyconnectome/seatabler>

- Report bugs at <https://github.com/flyconnectome/seatabler/issues>

## Author

**Maintainer**: Gregory Jefferis <jefferis@gmail.com>
([ORCID](https://orcid.org/0000-0002-0587-9355))

Authors:

- Gregory Jefferis <jefferis@gmail.com>
  ([ORCID](https://orcid.org/0000-0002-0587-9355))

Other contributors:

- Alexander Bates <alexander.shakeel.bates@gmail.com>
  ([ORCID](https://orcid.org/0000-0002-1195-0445)) \[contributor\]
