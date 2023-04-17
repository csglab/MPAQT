This document explains the scripts/steps used to generate matrix P

0) RUN_simReads.sh, simReads.R
First, simulated data are generated using the R simReads function

1)RUN_kallisto_bus.sh, kallisto_bus.sh	
Run kallisto bus on fastqs to map reads to equivalence classes (ECs)

2) parse_fq_read_names.sh
Next, read names are extracted from fastqs, giving a tsv with the read ID and the transcript of origin of that read, allowing for read counts to be made for each transcript-EC pair downstream 

3) wrapper_RUN_p_matrix_counts.sh , RUN_p_matrix_counts.sh, p_matrix_counts.R
Next, transcript-EC pair counts are done per-replicate. Since this is a computationally intensive step (40G of RAM), a job is submitted separately for each replicate using wrapper scripts. Counts are then saved in each replicate subdirectory as "ec.txs.joined.counts.Rds"

4) combine_replicate_counts.R 
Combining counts of the replicate "ec.txs.joined.counts.Rds" objects into one dataframe
saved as "rep_counts.24reps.Rds"

5) generate_p_matrix.R 
Generate sparse matrix from the combined counts file "rep_counts.24reps.Rds"

6) 01.convert_to_list.R
Convert p_matrix.Rds to a list format which is more efficient to work with

# Fit model

EC_counts_bustools.R
-Count number of reads in each EC
Usage (example):
~/projects/rrg-hsn/maposto/miniconda3/envs/r4/bin/Rscript /project/6007998/maposto/scripts/p_matrix_array/EC_counts_bustools.R --topdir=/project/6007998/maposto/PROJECTS/p_matrix_quant/output.kallisto_quant_bus.MDA-MB-231-LM2.SIM.Sept-23-2021/

7) 02.fit_model.v1.block_coordinate.R 

Fit 
Fit EC read counts to p matrix to generate coefficients for each column (transcript) of P
