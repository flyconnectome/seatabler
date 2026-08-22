# List the snapshots of a SeaTable base

SeaTable snapshots a base periodically, and a snapshot is the only way
back from a bad bulk update. This lists the snapshots available for a
base, so you can see how far back you can go and pick the one to restore
from in the web interface.

## Usage

``` r
seatable_snapshots(base_name, con = default_connection(), workspace_id = NULL)
```

## Arguments

- base_name:

  Name of the base.

- con:

  A
  [seatable_connection](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md).

- workspace_id:

  Workspace holding the base. Defaults to the connection's
  `workspace_id`, or is looked up with
  [`seatable_workspace_id()`](https://flyconnectome.github.io/seatabler/reference/seatable_workspace_id.md).

## Value

A data frame of snapshots, one row each, typically with the snapshot
name and its creation time. An empty data frame when the base has none.

## Details

Restoring is deliberately not wrapped: it is destructive, has no undo,
and belongs in the SeaTable UI where it asks for confirmation.

## Examples

``` r
if (FALSE) { # \dontrun{
seatable_snapshots("my_base", con = con)
} # }
```
