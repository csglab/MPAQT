# Migration notes: main

This branch belongs to the private staging repository `csglab/MPAQT_merged`.
The original MPAQT and mpaqt2 repositories have not been changed.
This is a fresh snapshot import; original commit history remains in the source
repositories and separately verified local Git bundles. Original licenses and
source authorship information are retained.

The migration removes legacy datasets, run outputs, reference indexes, the old
wiki gitlink, the workflow PowerPoint, development logs, and internal design
documents where present. Small workflow images, documentation, source code,
dependency specifications, and tests remain. Legacy branches require external
data/reference inputs and are preserved for reference, not certified runnable.

GitHub Pages publishing is disabled during private review. Existing links to
the original documentation site intentionally remain until public cutover.
Package/container registry names and existing release artifacts are unchanged;
do not run publishing scripts as a migration validation step.

`main` and `mpaqt-v2` start at the same commit. `mpaqt-v2` is the migration
snapshot, while subsequent development can continue on `main`.
The tags `v2.0.0` and `v2.4.0` point to cleaned historical release snapshots,
before repository-link and staging configuration changes.

Before a separately approved public cutover: choose the final repository name,
update repository and documentation URLs across maintained branches, configure
Pages, review protections/access, and verify releases and installation links.
Repository visibility must remain private until explicitly approved.

## Source mapping

| Source | New branch or tag | Source commit |
|---|---|---|
| `csglab/MPAQT:origin/archive` | `mpaqt-v0` | `01b56438e70fe8fc53f7ed01c51473375b2572a4` |
| `csglab/MPAQT:origin/main` | `mpaqt-v1` | `fe5011b5bb0b861461d963573257809f7d45ade6` |
| `csglab/mpaqt2:v2.0.0` | `v2.0.0` | `47ac1489050fdf1d8c208ba43a80d515bdb24f52` |
| `csglab/mpaqt2:origin/mpaqt-cli` | `mpaqt-v2-cli` | `a1f466c1b66923a460bfcf5ebc6ddb9458816aa8` |
| `csglab/mpaqt2:origin/mpaqt-r` | `mpaqt-v2-r` | `7cef1b97da1253c5f66bd0032820c0a71f3ab07a` |
| `csglab/mpaqt2:v2.4.0` | `v2.4.0` | `ccff2af44c9b16104bc171871d709e4c05e817c4` |
| `csglab/mpaqt2:origin/main` | `main and mpaqt-v2` | `289635cc5316cef8b06a4c5d05f7942d215f5010` |
| `csglab/mpaqt2:origin/gh-pages` | `gh-pages` | `5c1a92c8501e84dcc143f709a1b104247e575d78` |

The file `migration-manifest.json` lists imported commits and every excluded path. Import commits preserve every retained file byte and executable permission. Later staging commits change repository references, documentation notices, ignore rules, and CI configuration.

## Verification

All eight imported trees match their retained source files exactly. All reachable Git blobs are below 5 MiB. The existing release-asset checks and installation-harness checks pass; all 21 current R source files parse; `R CMD build --no-build-vignettes --no-manual` succeeds. Full installed-package tests and vignette builds were not run because this machine lacks required packages including `lme4` and `gpboost` (and the site builder `pkgdown`).

The GitHub inventory found no published releases or release attachments in either source repository. Existing issues, pull requests, settings, and wiki content are not imported as Git history; the originals remain available. Before deleting either original, separately preserve any GitHub-only material that should survive. No original repository may be deleted as part of this staging migration.
