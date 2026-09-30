sbatch --job-name=known-index-mpaqt \
    /home/saberi/projects/mpaqt/rebuttal/MPAQT/run_mpaqt.sh \
    --ref_txome_fa /home/saberi/projects/mpaqt/rebuttal/data/references/gencode.v47.annotation.gtf \
    --ref_annot_gtf /home/saberi/projects/mpaqt/rebuttal/data/references/gencode.v47.transcripts.fa \
    --mpaqt_index /home/saberi/projects/mpaqt/rebuttal/data/references/gencode.v47.annotation.mpaqt.index \
    --num_threads 16

sbatch --job-name=novel-index-mpaqt \
    /home/saberi/projects/mpaqt/rebuttal/MPAQT/run_mpaqt.sh \
    --ref_txome_fa /home/saberi/projects/mpaqt/rebuttal/data/references/neurondiff_isoseq.gencode_v47.GRCh38_p14.extended_annotations.sorted.gtf \
    --ref_annot_gtf /home/saberi/projects/mpaqt/rebuttal/data/references/neurondiff_isoseq.gencode_v47.GRCh38_p14.extended_annotations.transcripts.fasta \
    --mpaqt_index /home/saberi/projects/mpaqt/rebuttal/data/references/neurondiff_isoseq.gencode_v47.GRCh38_p14.extended_annotations.mpaqt.index \
    --num_threads 16
