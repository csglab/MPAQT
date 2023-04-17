#!/bin/bash

#reps=( $(seq 1 24 ) )
reps=( $(seq 1 24 ) )

#fq_dir=/home/maposto/scratch/sim_reads.24reps.1TPM.100mil
fq_dir=/home/maposto/scratch/p_mat.novel_MDA-MB-231_dup1.Sept-16-2021
for rep in ${reps[@]};do
mkdir $fq_dir/rep$rep
ls -d $fq_dir/rep$rep

#sample=sim.1TPM.100mil
sample=novel_MDA-MB-231_dup1
ls $fq_dir/$sample.$rep\_R1.fastq.gz $fq_dir/$sample.$rep\_R2.fastq.gz

#ls -d /home/maposto/scratch/kallisto_bus.P_mtx.Aug-3-2021/rep$rep/

#cat $fq_dir/$sample.$rep\_R1.fastq.gz | gunzip  | grep ^@R  | awk  '{gsub("\\|","\t",$0); print;}' |awk  '{gsub(":","\t",$0); print;}' | cut -f 1,2 > /home/maposto/scratch/kallisto_bus.P_mtx.Aug-3-2021/rep$rep/read_names.txt
cat $fq_dir/$sample.$rep\_R1.fastq.gz | gunzip  | grep ^@R  | awk  '{gsub("\\|","\t",$0); print;}' |awk  '{gsub(":","\t",$0); print;}' | cut -f 1,2 > $fq_dir/rep$rep/read_names.txt

done
