# rnaseq-alignment-flow

`taf-rnaseq-alignment-flow` is the alignment branch entry point for the
TAFFISH RNA-seq flow set. It reads a FASTQ sample table, optionally preprocesses
reads with fastp, aligns reads to a user-supplied HISAT2 index, sorts and
indexes BAM files with SAMtools, and writes alignment summaries, MultiQC,
commands, versions, methods, logs, and a manifest under one output directory.

Package identity:

- name: `rnaseq-alignment-flow`
- command: `taf-rnaseq-alignment-flow`
- kind: `flow`
- version: `0.1.0-r1`
- license: Apache-2.0

## RNA-seq Flow Position

This app is a reusable subflow in the TAFFISH bulk RNA-seq flow family. It can
be run directly when users need coordinate-sorted BAM files, and it is also
intended to serve the optional alignment/count branch of the future
`rnaseq-standard-flow` umbrella. The umbrella should reuse this flow's
`bam_files.tsv` contract rather than duplicate its HISAT2/SAMtools logic.

## Scope

r1 supports:

- single-end and paired-end FASTQ sample tables
- HISAT2 alignment from a prebuilt HISAT2 index
- optional fastp preprocessing with `--trim`
- SAMtools coordinate sorting and BAM indexing
- per-sample `flagstat` and `idxstats`
- `bam_files.tsv` for downstream count/QC flows
- MultiQC report generation
- complete flow provenance under `<outdir>/`

r1 deliberately does not build the HISAT2 index inside the flow. It also does
not run STAR, featureCounts, RSeQC, Qualimap, DESeq2, enrichment, or report
collection. Those are separate upstream or downstream flow responsibilities.

## Dependencies

The flow depends on exact TAFFISH tool versions:

| Dependency | Version | Role |
| --- | --- | --- |
| `taf-hisat2` | `2.2.2-r2` | HISAT2 alignment |
| `taf-samtools` | `1.23.1-r1` | BAM sorting, indexing, flagstat, idxstats |
| `taf-fastp` | `1.3.3-r3` | optional FASTQ preprocessing |
| `taf-multiqc` | `1.35-r2` | alignment report aggregation |

The script also uses ordinary shell utilities such as `awk`, `sed`, `sort`,
`find`, `mkdir`, `cp`, `rm`, `date`, and `wc` for validation and bookkeeping.
It does not call host-installed HISAT2, SAMtools, fastp, or MultiQC.

## Usage

Single-end HISAT2 alignment:

```sh
taf-rnaseq-alignment-flow \
  --samples samples.tsv \
  --index ref/hisat2/genome \
  --outdir align-out \
  --threads 4
```

Run with fastp preprocessing:

```sh
taf-rnaseq-alignment-flow \
  --samples samples.tsv \
  --index ref/hisat2/genome \
  --outdir align-out \
  --threads 4 \
  --trim
```

The `--index` argument is a HISAT2 index prefix, for example
`ref/hisat2/genome` when files such as `genome.1.ht2` exist. A directory may
also be supplied if it contains exactly one HISAT2 prefix.

If `rnaseq-index-flow` was run with `--genome-indexer hisat2`, use:

```sh
--index ref-out/03_results/hisat2_index/genome
```

## Parameters

Required:

- `--samples PATH`: FASTQ sample table.
- `--index PATH`: HISAT2 index prefix or a directory containing one prefix.
- `--outdir PATH`, `-o PATH`: output directory. Existing directories are
  refused unless `--force` is used.

Common:

- `--aligner hisat2`: aligner selector. r1 supports `hisat2` only; `star` is a
  planned later extension.
- `--threads N`, `-t N`: threads for HISAT2, SAMtools, and fastp. Default: `2`.
- `--trim`: run fastp before alignment.
- `--rna-strandness none|F|R|FR|RF`: optional HISAT2 RNA strandness argument.
  Default: `none`.
- `--min-mapq N`: if greater than zero, filter final BAM records by MAPQ after
  sorting. Default: `0`.
- `--keep-sam`: keep intermediate SAM files under `02_intermediate/sam/`.
  Default: remove SAM files after BAM sorting/indexing.
- `--force`: replace the standard rnaseq-alignment-flow outputs in an existing
  output directory.

## Sample Table

Single-end:

```text
sample_id	read1	condition	library_layout
S1	reads/S1.fq.gz	control	single-end
S2	reads/S2.fq.gz	treated	single-end
```

Paired-end:

```text
sample_id	read1	read2	condition	library_layout
S1	reads/S1_R1.fq.gz	reads/S1_R2.fq.gz	control	paired-end
S2	reads/S2_R1.fq.gz	reads/S2_R2.fq.gz	treated	paired-end
```

Rules:

- `sample_id` must be unique and contain only letters, digits, dot, underscore,
  or dash.
- `read1` is required and must point to a readable FASTQ file.
- `read2` is required only for `paired-end`.
- Relative FASTQ paths are resolved relative to the sample table location.
- Extra columns are ignored by this flow but preserved in upstream metadata
  when users keep their own project tables.

## Outputs

All flow-created outputs are written under `<outdir>/`:

```text
<outdir>/
  00_inputs/
    samples.tsv
  01_logs/
    flow.log
    steps/
      01_validate_inputs.log
      02_fastp.log
      03_align.log
      04_sort_index.log
      05_multiqc.log
  02_intermediate/
    alignment_inputs.tsv
    trimmed/
    sam/
  03_results/
    bam/
      S1.sorted.bam
      S1.sorted.bam.bai
    fastp/
    aligner_logs/
      S1.hisat2.summary.txt
      S1.flagstat.txt
      S1.idxstats.tsv
    alignment_summary.tsv
  04_reports/
    multiqc_report.html
    bam_files.tsv
    commands.sh
    versions.tsv
    methods.txt
    flow_summary.tsv
  run.manifest.json
```

Important files:

- `03_results/bam/*.sorted.bam`: coordinate-sorted BAM files.
- `03_results/bam/*.sorted.bam.bai`: BAM indexes.
- `04_reports/bam_files.tsv`: stable downstream BAM table.
- `03_results/alignment_summary.tsv`: per-sample read and mapping metrics.
- `04_reports/multiqc_report.html`: aggregated alignment report.
- `04_reports/commands.sh`: exact dependency commands used.
- `run.manifest.json`: inputs, parameters, dependency versions, counts, and
  output paths.

## Downstream Connection

The next alignment-branch flows consume `bam_files.tsv`:

```sh
taf-rnaseq-count-flow \
  --bams align-out/04_reports/bam_files.tsv \
  --annotation genes.gtf \
  --outdir count-out
```

```sh
taf-rnaseq-alignment-qc-flow \
  --bams align-out/04_reports/bam_files.tsv \
  --annotation-bed genes.bed \
  --gtf genes.gtf \
  --outdir alignment-qc-out
```

`rnaseq-report-flow` can also collect this output directory with
`--alignment-out align-out`.

## Resource Notes

HISAT2 alignment is usually lighter than STAR, but runtime and disk use still
scale with sample count, read depth, genome size, and whether SAM files are
kept. By default, intermediate SAM files are removed after BAM sorting to avoid
large temporary storage. For yeast-scale tests, 1-2 CPU threads are enough. For
larger genomes and many samples, use more threads and ensure the HISAT2 index
and output directory are on fast local storage.

## Boundaries

This flow is for alignment and BAM preparation. It does not decide whether an
alignment result is biologically good enough, and it does not replace deeper
BAM/RNA-seq QC. Use downstream count and alignment-QC flows for gene counting
and detailed RSeQC/Qualimap checks.

Smoke builds a tiny HISAT2 index from a toy reference and runs mixed
single-end/paired-end fixtures. Formal testing builds a temporary HISAT2 index
from the central yeast SGD reference and aligns a small real FASTQ subset from
the central yeast SNF2 mini dataset. The central data tree can be prepared with
`repos/apps/bio/flows/rna-seq/test-data/yeast/rnaseq-yeast-get-data`; downstream
formal tests read it via `TAFFISH_RNASEQ_TESTDATA` or the default local
`test-data/yeast/data/03_results` path.
