#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

#-------------------------
# Load configuration
#-------------------------
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
CONFIG_FILE="$SCRIPT_DIR/mirror.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Configuration file ($CONFIG_FILE) not found!"
  exit 1
fi
source "$CONFIG_FILE"

# Provide defaults if any variable is unset
URL_FILE=${URL_FILE:-"$SCRIPT_DIR/urls.txt"}
MIRROR_DIR=${MIRROR_DIR:-"$SCRIPT_DIR/mirror"}
LOG_FILE=${LOG_FILE:-"$SCRIPT_DIR/mirror.log"}
SUMMARY_FILE=${SUMMARY_FILE:-"$SCRIPT_DIR/mirror-summary.txt"}
MAX_LEVEL=${MAX_LEVEL:-0}
ACCEPT=${ACCEPT:-"*.html"}
REJECT=${REJECT:-""}
PARALLEL_JOBS=${PARALLEL_JOBS:-2}
USE_HEADLESS=${USE_HEADLESS:-"false"}
PUPPETEER_SCRIPT=${PUPPETEER_SCRIPT:-"$SCRIPT_DIR/render.js"}
BROWSER=${BROWSER:-"xdg-open"}

#-------------------------
# Pre-flight checks
#-------------------------
if [[ ! -f "$URL_FILE" ]]; then
  echo "URL list file ($URL_FILE) not found!"
  exit 1
fi

if [[ "$USE_HEADLESS" == "true" && ! -x "$PUPPETEER_SCRIPT" ]]; then
  echo "Headless mode enabled, but Puppeteer script not found or not executable: $PUPPETEER_SCRIPT"
  exit 1
fi

#-------------------------
# Handle -s/--select mode
#-------------------------
if [[ "${1:-}" == "-s" || "${1:-}" == "--select" ]]; then
  if ! command -v fzf >/dev/null; then
    echo "Error: fzf is not installed."
    exit 1
  fi

  echo "Scanning for mirrored .html files..."
  mapfile -t html_files < <(find "$MIRROR_DIR" -type f -name '*.html')
  if [[ ${#html_files[@]} -eq 0 ]]; then
    echo "No .html files found in $MIRROR_DIR."
    exit 0
  fi

  selected=$(printf '%s\n' "${html_files[@]}" | fzf --multi --prompt="Open file(s): ")
  [[ -z "$selected" ]] && exit 0

  echo "Opening in browser: $BROWSER"
  while IFS= read -r file; do
    "$BROWSER" "$file" &
  done <<< "$selected"
  exit 0
fi

#-------------------------
# Prepare directories & logs
#-------------------------
mkdir -p "$MIRROR_DIR"
: > "$LOG_FILE"
: > "$SUMMARY_FILE"

#-------------------------
# Helper: fetch sitemap URLs
#-------------------------
fetch_sitemap() {
  local base_url="$1"
  local sitemap_url="${base_url%/}/sitemap.xml"

  if curl --head --silent --fail "$sitemap_url" >/dev/null; then
    echo "→ Found sitemap: $sitemap_url"
    curl -s "$sitemap_url" \
      | grep -oP '(?<=<loc>)[^<]+' \
      | sed 's|/$||'
  fi
}

#-------------------------
# Build URL list
#-------------------------
TMP_URLS=$(mktemp)
trap 'rm -f "$TMP_URLS"' EXIT

# a) original URLs
grep -v '^\s*$' "$URL_FILE" >> "$TMP_URLS"

# b) sitemap expansion
while read -r url; do
  fetch_sitemap "$url" >> "$TMP_URLS"
done < <(grep -v '^\s*$' "$URL_FILE")

# c) dedupe
sort -u "$TMP_URLS" -o "$TMP_URLS"

#-------------------------
# Site download function
#-------------------------
download_site() {
  local url="$1"
  # Extract domain (handles ports, subdomains, etc.)
  local host="${url#*//}"
  host="${host%%/*}"

  # wget options
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
    "--domains=$host"
    "--directory-prefix=$MIRROR_DIR"
    --tries=3
    --timeout=30
    "--output-file=$LOG_FILE"
  )

  if [[ "$USE_HEADLESS" == "true" ]]; then
    local out_html="$MIRROR_DIR/$(echo "$url" \
      | sed 's|https\?://||;s|[/?&=]|_|g').html"
    node "$PUPPETEER_SCRIPT" "$url" "$out_html"
  else
    wget "${opts[@]}" "$url"
  fi
}

export -f download_site
export MIRROR_DIR LOG_FILE MAX_LEVEL ACCEPT REJECT USE_HEADLESS PUPPETEER_SCRIPT

#-------------------------
# Run parallel downloads
#-------------------------
echo "Starting mirror with $PARALLEL_JOBS parallel jobs…"

# disable exit-on-error so we can catch failures
set +e
parallel --jobs "$PARALLEL_JOBS" download_site :::: "$TMP_URLS"
par_exit=$?
set -e

if [[ $par_exit -ne 0 ]]; then
  echo "Warning: $par_exit parallel job(s) failed. See $LOG_FILE for details."
fi

#-------------------------
# Generate summary
#-------------------------
{
  echo "=== Mirror Summary: $(date) ==="
  echo "- Original start URLs: $(wc -l < "$URL_FILE")"
  echo "- URLs after sitemap expansion: $(wc -l < "$TMP_URLS")"
  echo "- Total files mirrored: $(find "$MIRROR_DIR" -type f | wc -l)"
  echo "- Total mirror size: $(du -sh "$MIRROR_DIR" | cut -f1)"
  echo "- Errors in log: $(grep -cEi 'error|failed' "$LOG_FILE")"
} >> "$SUMMARY_FILE"

echo "Mirror complete. Summary written to $SUMMARY_FILE."

# ensure a zero exit so ble.sh doesn’t show “exit 1”
exit 0
