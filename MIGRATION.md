# Migration notes: mpaqt-v2-cli

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
