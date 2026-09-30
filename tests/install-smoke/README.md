# MPAQT installation smoke tests

These scripts verify that MPAQT 2.4.0 can create a real index through each
published installation path:

- corrected Conda package `r-mpaqt=2.4.0=r43_1`;
- stable Apptainer image `library://csglab/mpaqt/mpaqt:2.4.0`;
- GitHub installation with `pak::pak("csglab/mpaqt2")`.

The tests generate a four-transcript, two-gene FASTA/GTF reference. Each gene
has two mostly shared isoform sequences with a small unique region, so the
reference exercises realistic ambiguous equivalence classes. All three
installations run the same `mpaqt_index()` assertions.

The Conda solves explicitly include the `defaults` channel because the
`r-gpboost` dependency is currently distributed from that channel.

## Known v2.4.0 indexing limitation

During development of this harness, an earlier toy reference containing only
uniquely mapping transcripts exposed a v2.4.0 type mismatch when a Kallisto
`matrix.ec` file contains only singleton ECs. `data.table::fread()` infers the
EC transcript column as integer, but the distance lookup later uses character
EC names. The paired-isoform reference used here represents the normal
ambiguous-EC use case and passes, but the singleton-only case remains
unresolved because this work intentionally does not modify R source.

Run all tests:

```bash
export GITHUB_PAT=...
tests/install-smoke/run-all.sh
```

The scripts keep the requested Conda environments, `mpaqt2` and
`mpaqt2-local`. They refuse to replace existing environments unless explicitly
requested:

```bash
tests/install-smoke/run-all.sh --recreate
```

Logs and generated indices are written under
`${MPAQT_INSTALL_SMOKE_ROOT:-/tmp/mpaqt-install-smoke}`.
