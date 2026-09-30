#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 OUTPUT_DIR" >&2
    exit 2
fi

output_dir="$1"
fasta="$output_dir/toy.fa"
gtf="$output_dir/toy.gtf"

mkdir -p "$output_dir"

generate_sequence() {
    local seed="$1"
    local length="$2"
    local mutation_position="$3"

    awk -v seed="$seed" -v seq_len="$length" -v mutation_position="$mutation_position" '
        BEGIN {
            bases = "ACGT"
            state = seed
            for (i = 1; i <= seq_len; i++) {
                state = (state * 1103515245 + 12345) % 2147483647
                base_index = (state % 4) + 1
                if (i == mutation_position) {
                    base_index = (base_index % 4) + 1
                }
                printf "%s", substr(bases, base_index, 1)
                if (i % 80 == 0 || i == seq_len) {
                    printf "\n"
                }
            }
        }
    '
}

: > "$fasta"
for transcript_spec in \
    "tx1 240 2401 0" \
    "tx2 240 2401 60" \
    "tx3 240 2403 0" \
    "tx4 240 2403 180"
do
    read -r transcript length seed mutation_position <<< "$transcript_spec"
    printf '>%s\n' "$transcript" >> "$fasta"
    generate_sequence "$seed" "$length" "$mutation_position" >> "$fasta"
done

{
    printf 'toy_chr1\tmpaqt_smoke\ttranscript\t1\t240\t.\t+\t.\tgene_id "gene1"; transcript_id "tx1"; gene_type "protein_coding"; transcript_type "protein_coding";\n'
    printf 'toy_chr1\tmpaqt_smoke\texon\t1\t240\t.\t+\t.\tgene_id "gene1"; transcript_id "tx1"; exon_number "1"; gene_type "protein_coding"; transcript_type "protein_coding";\n'
    printf 'toy_chr1\tmpaqt_smoke\ttranscript\t301\t540\t.\t+\t.\tgene_id "gene1"; transcript_id "tx2"; gene_type "protein_coding"; transcript_type "protein_coding";\n'
    printf 'toy_chr1\tmpaqt_smoke\texon\t301\t540\t.\t+\t.\tgene_id "gene1"; transcript_id "tx2"; exon_number "1"; gene_type "protein_coding"; transcript_type "protein_coding";\n'
    printf 'toy_chr1\tmpaqt_smoke\ttranscript\t601\t840\t.\t+\t.\tgene_id "gene2"; transcript_id "tx3"; gene_type "protein_coding"; transcript_type "protein_coding";\n'
    printf 'toy_chr1\tmpaqt_smoke\texon\t601\t840\t.\t+\t.\tgene_id "gene2"; transcript_id "tx3"; exon_number "1"; gene_type "protein_coding"; transcript_type "protein_coding";\n'
    printf 'toy_chr1\tmpaqt_smoke\ttranscript\t901\t1140\t.\t+\t.\tgene_id "gene2"; transcript_id "tx4"; gene_type "protein_coding"; transcript_type "protein_coding";\n'
    printf 'toy_chr1\tmpaqt_smoke\texon\t901\t1140\t.\t+\t.\tgene_id "gene2"; transcript_id "tx4"; exon_number "1"; gene_type "protein_coding"; transcript_type "protein_coding";\n'
} > "$gtf"

transcript_count="$(rg -c '^>' "$fasta")"
gtf_transcript_count="$(awk -F '\t' '$3 == "transcript" {count++} END {print count + 0}' "$gtf")"

[[ "$transcript_count" -eq 4 ]] || {
    echo "ERROR: expected four FASTA transcripts, found $transcript_count" >&2
    exit 1
}
[[ "$gtf_transcript_count" -eq 4 ]] || {
    echo "ERROR: expected four GTF transcripts, found $gtf_transcript_count" >&2
    exit 1
}

echo "Created toy reference:"
echo "  FASTA: $fasta"
echo "  GTF:   $gtf"
