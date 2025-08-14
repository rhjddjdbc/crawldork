#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
CONFIG_FILE="$SCRIPT_DIR/mirror.conf"

# Check dependencies
for cmd in ddgr jq wget parallel; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: '$cmd' is not installed."
    exit 1
  fi
done

# === Mirror Function ===
mirror_urls() {
  echo ""
  echo "Starting mirroring from urls.txt..."

  # Create default config if missing
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Configuration file not found. Creating default: $CONFIG_FILE"
cat > "$CONFIG_FILE" <<'EOF'
# Path to the input URL list
URL_FILE="./urls.txt"

# Directory where the mirrored content will be stored
MIRROR_DIR="./mirror"

# Log and summary file paths
LOG_FILE="./mirror.log"
SUMMARY_FILE="./mirror-summary.txt"

# Max depth for mirroring (0 = only target URL, 1 = follow links)
MAX_LEVEL=1

# Accept common web assets (HTML, stylesheets, scripts, images, fonts)
ACCEPT=""

# File types to reject (leave empty if none)
REJECT=""

# Number of parallel downloads
PARALLEL_JOBS=4

# Enable headless browser rendering (Puppeteer) if needed
USE_HEADLESS="false"

# Path to Puppeteer rendering script (used only when headless mode is enabled)
PUPPETEER_SCRIPT="./render.js"

# Browser used to open mirrored files
BROWSER="xdg-open"
EOF
    echo "Default configuration written to $CONFIG_FILE"
  fi

  # Now source the config
  source "$CONFIG_FILE"

  if [[ ! -f "$URL_FILE" ]]; then
    echo "URL list file ($URL_FILE) not found!"
    exit 1
  fi

  mkdir -p "$MIRROR_DIR"
  : > "$LOG_FILE"
  : > "$SUMMARY_FILE"

  fetch_sitemap() {
    local base_url="$1"
    local sitemap_url="${base_url%/}/sitemap.xml"
    if curl --head --silent --fail "$sitemap_url" >/dev/null; then
      echo "→ Found sitemap: $sitemap_url"
      curl -s "$sitemap_url" | grep -oP '(?<=<loc>)[^<]+' | sed 's|/$||'
    fi
  }

  TMP_URLS=$(mktemp)
  trap 'rm -f "$TMP_URLS"' EXIT

  grep -v '^\s*$' "$URL_FILE" >> "$TMP_URLS"
  while read -r url; do
    fetch_sitemap "$url" >> "$TMP_URLS"
  done < "$URL_FILE"
  sort -u "$TMP_URLS" -o "$TMP_URLS"

  download_site() {
    local url="$1"
    local host="${url#*//}"
    host="${host%%/*}"

    local opts=(
      --mirror
      "--level=$MAX_LEVEL"
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

    [[ -n "$ACCEPT" ]] && opts+=( "--accept=$ACCEPT" )
    [[ -n "$REJECT" ]] && opts+=( "--reject=$REJECT" )

    if [[ "$USE_HEADLESS" == "true" ]]; then
      local out_html="$MIRROR_DIR/$(echo "$url" | sed 's|https\?://||;s|[/?&=]|_|g').html"
      node "$PUPPETEER_SCRIPT" "$url" "$out_html"
    else
      wget "${opts[@]}" "$url"
    fi
  }

  export -f download_site
  export MIRROR_DIR LOG_FILE MAX_LEVEL ACCEPT REJECT USE_HEADLESS PUPPETEER_SCRIPT

  echo "Starting mirror with $PARALLEL_JOBS parallel jobs..."
  set +e
  parallel --jobs "$PARALLEL_JOBS" download_site :::: "$TMP_URLS"
  par_exit=$?
  set -e

  if [[ $par_exit -ne 0 ]]; then
    echo "Warning: $par_exit parallel job(s) failed. See $LOG_FILE for details."
  fi

  {
    echo "=== Mirror Summary: $(date) ==="
    echo "- Original start URLs: $(wc -l < "$URL_FILE")"
    echo "- URLs after sitemap expansion: $(wc -l < "$TMP_URLS")"
    echo "- Total files mirrored: $(find "$MIRROR_DIR" -type f | wc -l)"
    echo "- Total mirror size: $(du -sh "$MIRROR_DIR" | cut -f1)"
    echo "- Errors in log: $(grep -cEi 'error|failed' "$LOG_FILE" || true)"
  } >> "$SUMMARY_FILE"

  echo "Mirror complete. Summary written to $SUMMARY_FILE."
}

# === Interactive Mode Selector ===
echo "Choose a mode:"
echo "1) Google Dorking (search + optional mirror)"
echo "2) Mirror only (use existing urls.txt)"
echo "3) View mirrored HTML files"
read -rp "Choice (1/2/3): " mode

# === Mode 3: View mirrored files ===
if [[ "$mode" == "3" ]]; then
  if ! command -v fzf &>/dev/null; then
    echo "Error: 'fzf' is not installed. Please install it and try again."
    exit 1
  fi

  MIRROR_DIR="./mirror"
  [[ -f "./mirror.conf" ]] && source "./mirror.conf"

  read -rp "File types to search (e.g. pdf, docx). Leave empty for .html: " input_exts

  extensions=()
  if [[ -z "$input_exts" ]]; then
    extensions=("html")
  else
    IFS=',' read -ra raw_exts <<< "$input_exts"
    for ext in "${raw_exts[@]}"; do
      ext="${ext,,}"        # lowercase
      ext="${ext#.}"        # remove leading dot
      extensions+=("$ext")
    done
  fi

  # Build the find expression
  find_args=()
  for ext in "${extensions[@]}"; do
    find_args+=(-iname "*.${ext}" -o)
  done
  unset 'find_args[-1]'  # remove the trailing -o

  mapfile -t files < <(find "$MIRROR_DIR" -type f \( "${find_args[@]}" \))

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No matching files found."
    exit 0
  fi

  selected=$(printf '%s\n' "${files[@]}" | fzf --multi --prompt="Open file(s): ")
  [[ -z "$selected" ]] && exit 0

  BROWSER=${BROWSER:-xdg-open}
  while IFS= read -r file; do
    "$BROWSER" "$file" &
  done <<< "$selected"

  exit 0
fi

# === Mode 2: Mirror Only ===
if [[ "$mode" == "2" ]]; then
  mirror_urls
  exit 0
fi

# === Mode 1: Dorking + optional mirroring ===
echo "=== Google Dorking Tool (ddgr edition) ==="
echo "Leave input empty to skip a field."

read -rp "Keyword: " keyword
read -rp "site:<domain>: " site
read -rp "filetype:<type>: " filetype
read -rp "intitle:<text>: " intitle
read -rp "inurl:<text>: " inurl
read -rp "intext:<text>: " intext

query=""
[[ -n "$keyword" ]] && query+="$keyword "
[[ -n "$site" ]] && query+="site:$site "
[[ -n "$filetype" ]] && query+="filetype:$filetype "
[[ -n "$intitle" ]] && query+="intitle:$intitle "
[[ -n "$inurl" ]] && query+="inurl:$inurl "
[[ -n "$intext" ]] && query+="intext:$intext "
query="${query%% }"

echo -e "\nGenerated query:\n$query\n"

read -rp "How many pages do you want to search? (Max 3): " num_pages
num_pages="${num_pages:-3}"
if [[ "$num_pages" -gt 3 || "$num_pages" -lt 1 ]]; then
  echo "Invalid number of pages. Defaulting to 3."
  num_pages=3
fi

echo "Fetching up to $num_pages pages of results..."
> urls.txt

for page in $(seq 1 "$num_pages"); do
  echo "Fetching page $page..."
  temp_file="$(mktemp)"
  ddgr -n 25 --np --json "$query" > "$temp_file" 2> ddgr_error.log || true
  url_count=$(jq length < "$temp_file")

  if [[ "$url_count" -gt 0 ]]; then
    jq -r '.[].url' < "$temp_file" >> urls.txt
  else
    echo "No URLs returned. Retrying..."
    sleep 5
    ddgr -n 25 --np --json "$query" > "$temp_file" 2>> ddgr_error.log || true
    jq -r '.[].url' < "$temp_file" >> urls.txt
  fi

  rm -f "$temp_file"
  sleep 3
done

sort -u urls.txt -o urls.txt
sed -i '/^$/d' urls.txt
echo "Done. Results saved to 'urls.txt' ($(wc -l < urls.txt) URLs)."

read -rp "Do you want to mirror the URLs now? (y/N): " do_mirror
if [[ "$do_mirror" =~ ^[Yy]$ ]]; then
  mirror_urls
fi
