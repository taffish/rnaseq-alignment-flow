rnaseq-alignment-flow 0.1.0-r1

Purpose:
  Align RNA-seq FASTQ samples to a prebuilt HISAT2 index, then create
  coordinate-sorted BAM files, BAM indexes, alignment summaries, MultiQC,
  logs, commands, versions, methods, and a manifest under one output directory.

Flow family role:
  This is a TAFFISH RNA-seq subflow. It can be run directly to prepare sorted
  BAM files, and its bam_files.tsv contract is intended for the optional
  alignment/count branch of future rnaseq-standard-flow orchestration.

Usage:
  taf-rnaseq-alignment-flow \
    --samples samples.tsv \
    --index ref/hisat2/genome \
    --outdir align-out \
    [options]

Required inputs:
  --samples PATH
      FASTQ sample table with sample_id and read1 columns. read2 is required
      for paired-end samples. Relative read paths are resolved from the sample
      table directory.

  --index PATH
      HISAT2 index prefix, such as ref/hisat2/genome for files like
      genome.1.ht2. A directory may be used if it contains exactly one HISAT2
      prefix.
      If rnaseq-index-flow was run with --genome-indexer hisat2, pass
      ref-out/03_results/hisat2_index/genome.

Required output:
  --outdir PATH, -o PATH
      Output directory. The flow refuses to run if PATH already exists unless
      --force is used.

Common options:
  --aligner hisat2
      Aligner selector. r1 supports hisat2 only.

  --threads N, -t N
      Threads for HISAT2, SAMtools, and fastp. Default: 2.

  --trim
      Run fastp before alignment.

  --rna-strandness STRAND
      Optional HISAT2 RNA strandness argument. Default: none.
      Accepted values: none, F, R, FR, RF.

  --min-mapq N
      Filter final BAM records by MAPQ when N is greater than zero. Default: 0.

  --keep-sam
      Keep intermediate SAM files. Default: remove them after BAM sorting.

  --force
      Replace the standard rnaseq-alignment-flow outputs inside an existing
      output directory.

Output tree:
  <outdir>/00_inputs/samples.tsv
  <outdir>/01_logs/flow.log
  <outdir>/01_logs/steps/01_validate_inputs.log
  <outdir>/01_logs/steps/02_fastp.log
  <outdir>/01_logs/steps/03_align.log
  <outdir>/01_logs/steps/04_sort_index.log
  <outdir>/01_logs/steps/05_multiqc.log
  <outdir>/02_intermediate/alignment_inputs.tsv
  <outdir>/02_intermediate/trimmed/
  <outdir>/02_intermediate/sam/
  <outdir>/03_results/bam/
  <outdir>/03_results/aligner_logs/
  <outdir>/03_results/alignment_summary.tsv
  <outdir>/04_reports/bam_files.tsv
  <outdir>/04_reports/multiqc_report.html
  <outdir>/04_reports/commands.sh
  <outdir>/04_reports/versions.tsv
  <outdir>/04_reports/methods.txt
  <outdir>/04_reports/flow_summary.tsv
  <outdir>/run.manifest.json

Dependencies:
  taf-hisat2 2.2.2-r2
  taf-samtools 1.23.1-r1
  taf-fastp 1.3.3-r3
  taf-multiqc 1.35-r2

Boundaries:
  r1 does not build HISAT2 or STAR indexes, does not run STAR, featureCounts,
  RSeQC, Qualimap, DESeq2, enrichment, or project report collection. It prepares
  sorted BAM/BAI outputs for downstream count and alignment-QC flows.

Wrapper options:
  -h, --help       Show this help.
  -v, --version    Show package and command version.
  --compile        Print generated shell code instead of running it.
