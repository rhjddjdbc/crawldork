#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# 0. Load configuration
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
source "$SCRIPT_DIR/mirror.conf"

# 1. Prepare directories and logs
mkdir -p "$MIRROR_DIR"
: > "$LOG_FILE"
: > "$SUMMARY_FILE"
: > "$CHECKSUM_FILE"

# Helper: fetch sitemap and extract URLs
fetch_sitemap() {
  local base_url="$1"
  local sitemap_url="${base_url%/}/sitemap.xml"
  if curl --head --silent --fail "$sitemap_url" >/dev/null; then
    echo "→ Found sitemap: $sitemap_url"
    curl -s "$sitemap_url" \
      | grep -oP '(?<=<loc>)[^<]+' \
      | sed 's|/$||'   # strip trailing slash
  fi
}

# 2. Build a comprehensive URL list
TMP_URLS=$(mktemp)
trap "rm -f $TMP_URLS" EXIT

# a) add original URLs
grep -v '^\s*$' "$URL_FILE" >>"$TMP_URLS"

# b) add URLs from each sitemap
while read -r url; do
  fetch_sitemap "$url" >>"$TMP_URLS"
done < <(grep -v '^\s*$' "$URL_FILE")

# c) dedupe
sort -u "$TMP_URLS" -o "$TMP_URLS"

# 3. Define download function for GNU Parallel
download_site() {
  local url="$1"
  local domain
  domain=$(echo "$url" | awk -F[/:] '{print $4}')

  # Build the wget options array
  local opts=(
    --mirror
    "--level=$MAX_LEVEL"
    "--accept=$ACCEPT"
    "--reject=$REJECT"
    --convert-links
    --adjust-extension
    --page-requisites
    --no-parent
    --span-hosts
    "--domains=$domain"
    "--directory-prefix=$MIRROR_DIR"
    --tries=3
    --timeout=30
    "--output-file=$LOG_FILE"
  )
  $SHOW_PROGRESS && opts+=(--show-progress)

  if [[ "$USE_HEADLESS" == "true" ]]; then
    # If you need JS-rendered HTML, use your Puppeteer script:
    # node render.js <URL> <outfile.html>
    local out_html="$MIRROR_DIR/$(echo "$url" \
      | sed 's|https\?://||;s|[/?&=]|_|g').html"
    node "$PUPPETEER_SCRIPT" "$url" "$out_html"
  else
    wget "${opts[@]}" "$url"
  fi
}

export -f download_site
export MIRROR_DIR LOG_FILE MAX_LEVEL ACCEPT REJECT SHOW_PROGRESS USE_HEADLESS PUPPETEER_SCRIPT

# 4. Run parallel downloads
echo "Starting mirror with $PARALLEL_JOBS parallel jobs…"
parallel --jobs "$PARALLEL_JOBS" download_site :::: "$TMP_URLS"

# 5. Generate summary and checksums

# a) Summary report
{
  echo "=== Mirror Summary: $(date) ==="
  echo "- Original start URLs: $(wc -l < "$URL_FILE")"
  echo "- Total URLs after sitemap expansion: $(wc -l < "$TMP_URLS")"
  echo "- Total files mirrored:"
  find "$MIRROR_DIR" -type f | wc -l
  echo "- Total mirror size:"
  du -sh "$MIRROR_DIR" | cut -f1
  echo "- Errors found in log:"
  grep -Ei "error|failed" "$LOG_FILE" | wc -l
} >> "$SUMMARY_FILE"

# b) Checksums
echo "=== Checksums (${CHECKSUM_ALGO}) ===" >> "$CHECKSUM_FILE"
find "$MIRROR_DIR" -type f -print0 \
  | xargs -0 $CHECKSUM_ALGO \
  >> "$CHECKSUM_FILE"

echo "Done! See $SUMMARY_FILE and $CHECKSUM_FILE for details."
