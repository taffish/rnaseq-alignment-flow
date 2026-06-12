rnaseq-alignment-flow 0.2.0-r1

Purpose:
  Align RNA-seq FASTQ samples to a prebuilt HISAT2 index, then create
  coordinate-sorted BAM files, BAM indexes, alignment summaries, MultiQC,
  logs, commands, versions, methods, and a manifest under one output directory.

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

Key outputs:
  <outdir>/03_results/bam/*.sorted.bam
      Coordinate-sorted BAM files.

  <outdir>/03_results/bam/*.sorted.bam.bai
      BAM indexes.

  <outdir>/04_reports/bam_files.tsv
      Stable BAM table for count and alignment-QC flows.

  <outdir>/03_results/alignment_summary.tsv
      Per-sample mapping summary.

  <outdir>/04_reports/multiqc_report.html
      Aggregated alignment report.

  <outdir>/04_reports/
      commands.sh, versions.tsv, methods.txt, flow_summary.tsv, and provenance.

Upstream/downstream:
  Upstream:
    rnaseq-index-flow can provide hisat2_index/genome.

  Downstream:
    rnaseq-count-flow and rnaseq-alignment-qc-flow consume bam_files.tsv.
    rnaseq-report-flow can collect the alignment output directory.

Advanced step passthrough:
  Optional expert slots for native tool parameters. They default to empty
  and are not needed for normal use.

  @fastp-pe-step: ... @: fastp paired-end trimming.
  @fastp-se-step: ... @: fastp single-end trimming.
  @hisat2-align-pe-step: ... @: HISAT2 paired-end alignment.
  @hisat2-align-se-step: ... @: HISAT2 single-end alignment.
  @samtools-sort-step: ... @: samtools sort.
  @samtools-index-step: ... @: samtools index for sorted BAM.
  @samtools-quickcheck-step: ... @: samtools quickcheck.
  @samtools-flagstat-step: ... @: samtools flagstat.
  @samtools-idxstats-step: ... @: samtools idxstats.
  @samtools-mapq-filter-step: ... @: optional samtools view MAPQ filter.
  @samtools-mapq-index-step: ... @: samtools index for MAPQ-filtered BAM.
  @multiqc-step: ... @: MultiQC report generation.

Boundaries:
  r1 does not build HISAT2 or STAR indexes, does not run STAR, featureCounts,
  RSeQC, Qualimap, DESeq2, enrichment, or project report collection. It prepares
  sorted BAM/BAI outputs for downstream count and alignment-QC flows.

Detailed documentation:
  https://github.com/taffish/rnaseq-alignment-flow

Wrapper options:
  -h, --help       Show this help.
  -v, --version    Show package and command version.
  --compile        Print generated shell code instead of running it.
