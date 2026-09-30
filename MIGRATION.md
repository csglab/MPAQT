# Repository migration

The public repository is `csglab/MPAQT`. It was prepared privately under the name
`csglab/MPAQT_merged`. The original repository is retained as
`csglab/MPAQT_legacy`; its code and history were not deleted or rewritten.
The separate private `csglab/mpaqt2` repository is unchanged.

## Versions

| Branch | Original source |
|---|---|
| `mpaqt-v0` | Original MPAQT `archive` branch, excluding legacy datasets and generated outputs |
| `mpaqt-v1` | Original MPAQT `main` branch, excluding the reference index |
| `main` and `mpaqt-v2` | Latest `mpaqt2/main`, including changes after v2.4.0 |
| `mpaqt-v2-cli` | Preserved `mpaqt2/mpaqt-cli` source snapshot |
| `mpaqt-v2-r` | Preserved `mpaqt2/mpaqt-r` source snapshot |
| `gh-pages` | Published documentation files |

`main` and `mpaqt-v2` are equal at public cutover. Subsequent development can
continue on `main`; `mpaqt-v2` does not synchronize automatically.
The original CLI and R snapshots were already ancestors of `mpaqt2/main`.
Legacy versions require external reference/data inputs and are retained for reference.

## Tags

| Tag | Original source commit | Imported commit | Verification |
|---|---|---|---|
| `v2.0.0` | `47ac1489050fdf1d8c208ba43a80d515bdb24f52` | `a84ecad51958f0bd88583ee6f62bfc4724413047` | All 245 retained files match; only `log.txt` excluded |
| `v2.4.0` | `ccff2af44c9b16104bc171871d709e4c05e817c4` | `b7a6c99837badecfc5740e9314e0e358789cd5b7` | All 259 files and the entire tree match |

These annotated tags reproduce the original tagged contents on fresh history.
Their commit IDs changed during import; the tags in the original `mpaqt2`
repository were not moved. Historical URLs inside tagged files remain unchanged.
Both tags can be checked out or downloaded from the repository's Tags page.
They are Git tags, not separate GitHub Releases with binary attachments.

## Documentation and installation

The website is https://csglab.github.io/MPAQT/ and the current GitHub installation is:

```r
pak::pak("csglab/MPAQT")
```

README files intentionally remain identical to their original source versions,
including historical URLs and private-repository notices. Current installation
instructions are on the website. The documentation publishing workflow normalizes
generated website links and notices without modifying the preserved README files.
The pkgdown workflow rebuilds `gh-pages`; Publish documentation deploys that branch.

## Verification and provenance

All eight imports were compared with their sources, including file modes.
Both release tags and the main, CLI, and R branches built as R packages with
vignette/manual generation disabled. Source parsing, release configuration checks,
and installation-harness checks passed. Full runtime tests remain unverified on
the migration machine because required R packages including `lme4` and `gpboost`
were unavailable. Package builds do not establish full runtime correctness.

The new history excludes legacy datasets, outputs, indexes, the old wiki gitlink,
the workflow presentation, development logs, and internal design documents.
Source code, licenses, small documentation assets, dependencies, and tests remain.
`migration-manifest.json` on main records original source commits and exclusions;
its source names describe the repositories at import time, before renaming.
Complete source Git bundles and detailed validation reports are retained locally.
Original issues, stars, settings, and wiki content stay with their original repositories.

For an existing clone of the original MPAQT, update its remote to
`git@github.com:csglab/MPAQT_legacy.git`. Use a fresh clone of the new MPAQT for
development so the old large-file history is not pushed back into the cleaned repository.
