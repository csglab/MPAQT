#!/bin/bash
set -eo pipefail

CWD='/home/saberi/projects/mpaqt'
MPAQT_DIR="${CWD}/MPAQT"
tmp_dir='/home/saberi/projects/mpaqt/tmp'
NUM_THREADS=16

export MPAQT_DIR=$MPAQT_DIR
export PATH=$MPAQT_DIR:$PATH
export TMPDIR="${tmp_dir}"

# mpaqt index \
#     --ref_txome ${CWD}/data/references/gencode.v47.transcripts.fa \
#     --ref_annot ${CWD}/data/references/gencode.v47.annotation.gtf \
#     --output ${CWD}/data/references/gencode.v47.annotation.index \
#     --num_threads ${NUM_THREADS} \
#     --tmp_dir ${tmp_dir}

# mpaqt index \
#     --ref_txome ${CWD}/data/references/neurondiff_isoseq.gencode_v47.GRCh38_p14.extended_annotations.transcripts.fasta \
#     --ref_annot ${CWD}/data/references/neurondiff_isoseq.gencode_v47.GRCh38_p14.extended_annotations.sorted.biotyped.gtf \
#     --output ${CWD}/data/references/neurondiff_isoseq.gencode_v47.GRCh38_p14.extended_annotations.index \
#     --num_threads ${NUM_THREADS} \
#     --tmp_dir ${tmp_dir}

projects=(
	'gencode.v47.annotation'
	'neurondiff_isoseq.gencode_v47.GRCh38_p14.extended_annotations'
)

samples=(
	'hESC_Day0_1' 'hESC_Day0_2'
	'SOX10_Day41_1' 'SOX10_Day41_2'
	'SOX10_Day61_1' 'SOX10_Day61_2'
)

for project in "${projects[@]}"; do
	mpaqt create project \
		--index ${CWD}/data/references/${project}.index.mpaqt \
		${project}
done

for project in "${projects[@]}"; do
	mpaqt create sample \
		--project $project \
		${samples[@]}
done

for project in "${projects[@]}"; do
    mkdir -p data/bus/${project}
done

for project in "${projects[@]}"; do
    for sample in "${samples[@]}"; do
        echo "Processing ${project} ${sample}"
        mkdir -p ${CWD}/data/bus/${project}/${sample}
    done
done

for project in "${projects[@]}"; do
    for sample in "${samples[@]}"; do
        (kallisto bus \
            --index=${CWD}/data/references/${project}.index.kallisto \
            --paired \
            --technology=bulk \
            --output-dir=${CWD}/data/bus/${project}/${sample} \
            ${CWD}/data/raw/short-read/${sample}_1.fastq.gz \
            ${CWD}/data/raw/short-read/${sample}_2.fastq.gz) &
    done
done
wait

for project in "${projects[@]}"; do
    for sample in "${samples[@]}"; do
        mpaqt prepare short-read \
            --project ${project} \
            --sample ${sample} \
            --bus data/bus/${project}/${sample}/output.bus \
            --matrix_ec data/bus/${project}/${sample}/matrix.ec
    done
done

for project in "${projects[@]}"; do
    for sample in "${samples[@]}"; do
        awk -F'\t' -v sample="${sample}" '
            NR==1 {
                for (i=1; i<=NF; i++) {
                    if ($i=="TXNAME") tx=i
                    if ($i=="neurondiff_isoseq."sample".flnc.sorted") cnt=i
                }
                print "transcript_id\tcount"
            }
            NR>1 {
                print $tx"\t"$cnt
            }
        ' ${CWD}/data/quants/${project}/counts_transcript.txt \
        > ${CWD}/data/quants/${project}/${sample}.counts_transcript.txt

        mpaqt prepare long-read \
            --project ${project} \
            --sample ${sample} \
            --counts ${CWD}/data/quants/${project}/${sample}.counts_transcript.txt
    done
done

for project in "${projects[@]}"; do
    for sample in "${samples[@]}"; do
        (mpaqt quant \
            --project ${project} \
            --sample ${sample}) &
    done
done
wait
