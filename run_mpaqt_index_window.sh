conda activate mpaqt

CWD='/home/saberi/projects/mpaqt'
MPAQT_DIR="${CWD}/MPAQT"
# tmp_dir='/large_storage/goodarzilab/saberi/mpaqt/tmp'

export MPAQT_DIR=${MPAQT_DIR}
export PATH=${MPAQT_DIR}:$PATH
# export TMPDIR="${tmp_dir}"

# num_threads=${SLURM_CPUS_PER_TASK}
data_dir='/large_storage/goodarzilab/saberi/mpaqt/benchmarks'

echo "MPAQT ————— Generating index"

### Threads
num_threads=8
kallisto_threads=${num_threads}

TMPDIR='/large_storage/goodarzilab/saberi/mpaqt/tmp/tmp/tmp_window'
CWD=${TMPDIR}
mkdir -p ${CWD} ${CWD}/p-matrix ${CWD}/cov-matrix
export TMPDIR=${CWD}

### Input directories and files
SRC=${MPAQT_DIR}/src

ref_txome='/home/saberi/projects/mpaqt/rebuttal/data/spike-ins/gencode.v47.sequins.v2.4.transcripts.width60.fa'
ref_annot='/home/saberi/projects/mpaqt/rebuttal/data/spike-ins/gencode.v47.sequins.v2.4.annotation.gtf'
kallisto_index='/home/saberi/projects/mpaqt/rebuttal/data/spike-ins/gencode.v47.sequins.v2.4.window.index.kallisto'
output_index='/home/saberi/projects/mpaqt/rebuttal/data/spike-ins/gencode.v47.sequins.v2.4.window.index'

# num_reps=1

num_reads=2500000000
lib_size=${num_reads}
max_lib_size=100000000
half_max_lib_size=$((max_lib_size / 2))

echo "——————————— Generating P matrix"
seq 1 ${num_reps} | xargs -I{} -P${mpaqt_threads} bash -c "
  bash ${SRC}/create_pmat_replicate.sh \
    --rep={} \
    --topdir=${CWD}/p-matrix \
    --mode=${args[--mode]} \
    --ref_txome=${ref_txome} \
    --KALLISTO_IDX=${kallisto_index} \
    --scripts=${SRC} \
    --lib_size=${lib_size} \
    --kallisto_num_threads=${kallisto_threads}"

bash ${SRC}/combine_pmat_replicates.sh \
    --topdir=${CWD}/p-matrix \
    --scripts=${SRC} \
    --reps=${num_reps}

echo "——————————— Generating covariate matrix"
Rscript ${SRC}/R/generate_covMx.R \
    --topdir=${CWD}/cov-matrix \
    --fasta=${ref_txome} \
    --gtf=${ref_annot} \
    --P=${CWD}/p-matrix/P.Rds

echo "——————————— Finalizing MPAQT index"
Rscript ${SRC}/R/generate_mpaqt_index.R \
    --p_matrix=${CWD}/p-matrix/P.Rds \
    --cov_matrix=${CWD}/cov-matrix/covMx.Rds \
    --output=${output_index}.mpaqt

echo "——————————— Index has been generated successfully and stored in ${output_index}.mpaqt"
# rm -rf ${TMPDIR}
