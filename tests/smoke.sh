#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
project_dir=$(CDPATH= cd "$script_dir/.." && pwd)
bio_apps_dir=$(CDPATH= cd "$project_dir/../../../.." && pwd)
index_flow_dir=$(CDPATH= cd "$project_dir/../rnaseq-index-flow" && pwd)

for target_dir in \
    "$bio_apps_dir/tools/hisat2/target" \
    "$bio_apps_dir/tools/samtools/target" \
    "$bio_apps_dir/tools/fastp/target" \
    "$bio_apps_dir/tools/multiqc/target" \
    "$bio_apps_dir/tools/agat/target" \
    "$bio_apps_dir/tools/gffread/target" \
    "$bio_apps_dir/tools/salmon/target" \
    "$bio_apps_dir/tools/kallisto/target" \
    "$index_flow_dir/target"
do
    if [ -d "$target_dir" ]; then
        PATH="$target_dir:$PATH"
    fi
done
export PATH

if ! command -v taf >/dev/null 2>&1; then
    echo "smoke: taf command not found in PATH." >&2
    exit 127
fi

if ! command -v taffish >/dev/null 2>&1; then
    echo "smoke: taffish command not found in PATH." >&2
    exit 127
fi

for dep in \
    taf-hisat2-v2.2.2-r2 \
    taf-samtools-v1.23.1-r1 \
    taf-fastp-v1.3.3-r3 \
    taf-multiqc-v1.35-r2
do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "smoke: dependency wrapper not found in PATH: $dep" >&2
        exit 127
    fi
done

TAFFISH_CONTAINER_BACKEND=${TAFFISH_CONTAINER_BACKEND:-podman}
export TAFFISH_CONTAINER_BACKEND
TAF_HISTORY_MODE=${TAF_HISTORY_MODE:-off}
export TAF_HISTORY_MODE

tmpdir=$(mktemp -d "$project_dir/.taf-smoke.XXXXXX")
cleanup() {
    cd "$project_dir" 2>/dev/null || :
    rm -rf "$tmpdir"
}
trap cleanup EXIT INT TERM HUP

cd "$project_dir"

echo "[SMOKE] taf check"
taf check

echo "[SMOKE] taf build"
taf build

flow_cmd="$project_dir/target/taf-rnaseq-alignment-flow-v0.2.0-r1"
if [ ! -x "$flow_cmd" ]; then
    echo "smoke: built flow command is missing or not executable: $flow_cmd" >&2
    exit 1
fi

echo "[SMOKE] help and version"
"$flow_cmd" --help >/dev/null
"$flow_cmd" --version >/dev/null

run_dir="$tmpdir/run"
mkdir -p "$run_dir"

cat > "$run_dir/annotation.gff3" <<'EOF'
##gff-version 3
chrTiny	smoke	gene	1	180	.	+	.	ID=geneTiny;Name=geneTiny
chrTiny	smoke	mRNA	1	180	.	+	.	ID=txTiny;Parent=geneTiny
chrTiny	smoke	exon	1	180	.	+	.	ID=exonTiny;Parent=txTiny
EOF

echo "[SMOKE] build upstream rnaseq-index-flow"
(
    cd "$index_flow_dir"
    taf check
    taf build
)
index_flow_cmd="$index_flow_dir/target/taf-rnaseq-index-flow-v0.2.0-r1"
if [ ! -x "$index_flow_cmd" ]; then
    echo "smoke: built index flow command is missing or not executable: $index_flow_cmd" >&2
    exit 1
fi

echo "[SMOKE] setup HISAT2 index via rnaseq-index-flow target"
(
    cd "$run_dir"
    "$index_flow_cmd" \
        --genome "$project_dir/testdata/genome.fa" \
        --annotation "$run_dir/annotation.gff3" \
        --outdir ref-out \
        --threads 1 \
        --indexer salmon \
        --genome-indexer hisat2 \
        --kmer 15
)
test -s "$run_dir/ref-out/03_results/hisat2_index/genome.1.ht2"

echo "[SMOKE] rnaseq-alignment-flow tiny fixture"
(
    cd "$run_dir"
    "$flow_cmd" \
        --samples "$project_dir/testdata/samples.tsv" \
        --index "$run_dir/ref-out/03_results/hisat2_index/genome" \
        --outdir align-out \
        --threads 1 \
        --trim \
        @multiqc-step: --quiet @:
)
cd "$project_dir"

out="$run_dir/align-out"

echo "[SMOKE] output checks"
test -s "$out/00_inputs/samples.tsv"
test -s "$out/01_logs/flow.log"
test -s "$out/01_logs/steps/01_validate_inputs.log"
test -s "$out/01_logs/steps/02_fastp.log"
test -s "$out/01_logs/steps/03_align.log"
test -s "$out/01_logs/steps/04_sort_index.log"
test -s "$out/01_logs/steps/05_multiqc.log"
test -s "$out/02_intermediate/alignment_inputs.tsv"
test -s "$out/03_results/bam/tiny_se.sorted.bam"
test -s "$out/03_results/bam/tiny_se.sorted.bam.bai"
test -s "$out/03_results/bam/tiny_pe.sorted.bam"
test -s "$out/03_results/bam/tiny_pe.sorted.bam.bai"
test -s "$out/03_results/aligner_logs/tiny_se.flagstat.txt"
test -s "$out/03_results/aligner_logs/tiny_pe.hisat2.summary.txt"
test -s "$out/03_results/alignment_summary.tsv"
test -s "$out/04_reports/bam_files.tsv"
test -s "$out/04_reports/multiqc_report.html"
test -s "$out/04_reports/commands.sh"
test -s "$out/04_reports/versions.tsv"
test -s "$out/04_reports/methods.txt"
test -s "$out/04_reports/flow_summary.tsv"
test -s "$out/run.manifest.json"

grep -F 'tiny_se' "$out/04_reports/bam_files.tsv" >/dev/null
grep -F 'tiny_pe' "$out/03_results/alignment_summary.tsv" >/dev/null
grep -F 'taf-hisat2-v2.2.2-r2' "$out/04_reports/commands.sh" >/dev/null
grep -F -- '--quiet --quiet' "$out/04_reports/commands.sh" >/dev/null
grep -F 'taf-samtools	1.23.1-r1' "$out/04_reports/versions.tsv" >/dev/null
grep -F 'sample_count	2' "$out/04_reports/flow_summary.tsv" >/dev/null
grep -F '"flow": "rnaseq-alignment-flow"' "$out/run.manifest.json" >/dev/null
if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool "$out/run.manifest.json" >/dev/null
fi

echo "[SMOKE] existing outdir is refused"
if (
    cd "$run_dir"
    "$flow_cmd" \
        --samples "$project_dir/testdata/samples.tsv" \
        --index "$run_dir/ref-out/03_results/hisat2_index/genome" \
        --outdir align-out
) >/dev/null 2>&1; then
    echo "smoke: existing outdir was not refused." >&2
    exit 1
fi

echo "[SMOKE] --force rerun"
(
    cd "$run_dir"
    "$flow_cmd" \
        --samples "$project_dir/testdata/samples.tsv" \
        --index "$run_dir/ref-out/03_results/hisat2_index/genome" \
        --outdir align-out \
        --threads 1 \
        --force
)
test -s "$out/03_results/bam/tiny_se.sorted.bam"
grep -F 'trim	false' "$out/04_reports/flow_summary.tsv" >/dev/null

stray=$(find "$run_dir" -mindepth 1 -maxdepth 1 ! -name align-out ! -name ref-out ! -name annotation.gff3 -print)
if [ -n "$stray" ]; then
    echo "smoke: flow wrote unexpected files outside outdir:" >&2
    printf '%s\n' "$stray" >&2
    exit 1
fi

echo "[SMOKE] ok"
