# Crawldork

**Crawldork** is a Bash-based tool for privacy-respecting web reconnaissance and local mirroring. It allows you to craft advanced search queries, extract URLs, mirror web content locally, and browse downloaded files interactively — all from the terminal.

---

## Features

* Custom web search via `ddgr` (DuckDuckGo CLI)
* Optional mirroring of URLs with `wget`
* Automatic sitemap expansion
* Parallel downloads using `GNU parallel`
* Optional headless browser rendering via Puppeteer
* Interactive file viewer (e.g., HTML, PDF) with `fzf`

---

## Requirements

Ensure the following tools are installed on your system:

* `bash`
* `ddgr`
* `jq`
* `wget`
* `parallel`
* `fzf` (required for interactive file browsing)
* `xdg-open` (or any browser launcher)
* `node` (only if headless rendering is enabled)

### Debian / Ubuntu

```bash
sudo apt update
sudo apt install ddgr jq wget parallel fzf
```

### Arch / Manjaro

```bash
sudo pacman -S ddgr jq wget parallel fzf
```

If you use `yay` or another AUR helper, you can install optional packages like `xdg-utils` and `nodejs`:

```bash
yay -S xdg-utils nodejs
```

---

## Usage

Run the script:

```bash
./crawldork.sh
```

You will be prompted to choose a mode:

### Mode 1: Search + Optional Mirroring

* Builds a search query (e.g. `site:example.com filetype:pdf`)
* Fetches URLs using `ddgr`
* Saves results to `urls.txt`
* Optionally mirrors the content using `wget`

### Mode 2: Mirror Only

* Uses existing `urls.txt`
* Expands sitemap links
* Downloads content in parallel
* Stores results in the `mirror/` directory

### Mode 3: View Mirrored Files

* Searches for mirrored files by extension (e.g. `.html`, `.pdf`)
* Lets you select and open files via `fzf`
* Opens in your system browser (e.g. `xdg-open`)

---

## Configuration

If not present, a default `mirror.conf` is created. You can customize:

```bash
# mirror.conf

URL_FILE="./urls.txt"
MIRROR_DIR="./mirror"
LOG_FILE="./mirror.log"
SUMMARY_FILE="./mirror-summary.txt"
MAX_LEVEL=1
ACCEPT=""
REJECT=""
PARALLEL_JOBS=4
USE_HEADLESS="false"
PUPPETEER_SCRIPT="./render.js"
BROWSER="xdg-open"
```

---

## Example Workflow

1. Start the script:

   ```bash
   ./crawldork.sh
   ```

2. Select **Mode 1** and enter a search query.

3. Save discovered URLs and choose whether to mirror them.

4. Later, use **Mode 3** to browse and open downloaded files.

---

## Notes

* Uses `wget`'s mirroring mode with asset downloading and link conversion.
* Automatically attempts to find and parse `sitemap.xml` for each URL.
* Optional Puppeteer support allows for JavaScript-rendered content.

---

## License

This tool is licensed under the MIT License. Use it responsibly and ethically, in accordance with applicable laws and website terms of use.
