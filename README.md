# Web-Crawler

This script allows you to mirror websites locally by downloading all the pages, resources, and links, optionally using a headless browser for JavaScript-rendered content. It includes features like parallel downloading, sitemap extraction, and the ability to browse the downloaded files via `fzf`.

## Features

* **Parallel Downloads**: Uses `GNU Parallel` for efficient downloading of multiple sites.
* **Sitemap Extraction**: Automatically fetches and parses sitemaps from websites for efficient URL discovery.
* **Selective File Opening**: Use `fzf` to select and open downloaded HTML files in a browser.
* **Headless Browser Support**: Supports downloading JavaScript-rendered HTML using Puppeteer (optional).

## Requirements

Before using the script, make sure you have the following tools installed:

* `wget` (for downloading files)
* `parallel` (for parallel execution)
* `fzf` (for file selection, optional for browsing)
* `node.js` (for Puppeteer support, if needed)
* `curl` (for fetching sitemaps)

You can install the necessary packages using:

```bash
sudo apt update
sudo apt install wget parallel fzf curl nodejs npm
```

For Puppeteer, you'll also need to install it via npm:

```bash
npm install puppeteer
```

## Setup

1. Clone or download this repository.
2. Place your configuration file (`mirror.conf`) in the same directory as the script.

### Example `mirror.conf`:

```bash
# URL_FILE: Path to a file containing a list of URLs to start the mirroring process.
URL_FILE="./urls.txt"

# MIRROR_DIR: Directory where the mirrored files will be stored.
MIRROR_DIR="./mirrored_files"

# LOG_FILE: Path to the log file where download errors will be logged.
LOG_FILE="./mirror.log"

# SUMMARY_FILE: Path to the summary report.
SUMMARY_FILE="./summary.txt"

# CHECKSUM_FILE: Path to store checksums (disabled in this version).
CHECKSUM_FILE="./checksums.txt"

# MAX_LEVEL: Maximum depth to mirror.
MAX_LEVEL=5

# ACCEPT: File extensions to accept (e.g., .html, .css, .js).
ACCEPT="html,css,js,png,jpg,gif"

# REJECT: File extensions to reject (e.g., .pdf, .mp3).
REJECT="pdf,mp3"

# Use a headless browser to render JS (optional).
USE_HEADLESS=true
PUPPETEER_SCRIPT="./render.js"  # Path to your Puppeteer script.
PARALLEL_JOBS=2  # Number of parallel download jobs.
```

## Usage

### 1. Basic Usage: Mirror a Website

To start mirroring the websites listed in `URL_FILE`, simply run the script:

```bash
./mirror.sh
```

This will:

* Download the content of the sites defined in `URL_FILE`.
* Parse the sitemaps of the sites to discover additional URLs.
* Mirror the websites to `MIRROR_DIR`.

### 2. Select and Open HTML Files in Browser

If you want to select and open the downloaded HTML files in your browser using `fzf`, use the `-s` or `--select` flag:

```bash
./mirror.sh -s
```

This will:

* Scan the `MIRROR_DIR` for `.html` files.
* Use `fzf` to allow you to select files.
* Open the selected files in the browser.

### 3. Customize the Number of Parallel Jobs

You can adjust the number of parallel download jobs by modifying the `PARALLEL_JOBS` variable in `mirror.conf`. This will control the concurrency of the downloads.

## Troubleshooting

* **Missing Dependencies**: Make sure all dependencies are installed, including `wget`, `parallel`, `fzf`, `curl`, and `node.js`.
* **File Paths**: Double-check that the `URL_FILE`, `MIRROR_DIR`, and `PUPPETEER_SCRIPT` paths are correct in your `mirror.conf`.
* **Sitemap Issues**: If the script doesn't find a sitemap, it will skip that website, but the script will still attempt to download any other available resources.

## License

This script is released under the MIT License. Feel free to use and modify it as per your needs.
