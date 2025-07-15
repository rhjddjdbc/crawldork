# Web-Crawler

This project is licensed under the MIT License — a permissive open-source license that allows broad use, modification, and distribution of the software. You are free to integrate this script into commercial environments, research workflows, educational platforms, or personal tools, as long as the original license terms and attribution are preserved.

## Overview

This Bash-based utility streamlines website mirroring across multiple domains and URL sources. It leverages powerful Unix tools (`wget`, `curl`, `GNU parallel`) to perform fast and scalable downloads of entire site structures. It also integrates optional headless rendering support using Puppeteer for JavaScript-driven content.

Use cases include digital forensics audits, site backups, documentation archiving, penetration testing, and research.

## Features

- Configurable workflow via `mirror.conf`  
- Automatic sitemap.xml discovery and URL expansion  
- Concurrent downloads with `GNU parallel`  
- Optional headless rendering with Puppeteer  
- URL deduplication and domain enforcement  
- Error logging and summary reports  
- Checksum generation (e.g., MD5, SHA256)

## Requirements

- Bash (with `set -euo pipefail`)  
- Core utilities: `wget`, `curl`, `sed`, `grep`, `awk`  
- `GNU parallel`  
- Optional: Node.js & Puppeteer for JS rendering  

## Configuration

Edit `mirror.conf` to set:

- `MIRROR_DIR` — destination directory  
- `URL_FILE` — newline-separated seed URLs  
- `MAX_LEVEL`, `ACCEPT`, `REJECT` — wget filters  
- `SHOW_PROGRESS`, `USE_HEADLESS`, `PUPPETEER_SCRIPT`  
- `PARALLEL_JOBS` — number of parallel workers  
- `CHECKSUM_ALGO` — e.g. `sha256sum`  
- `LOG_FILE`, `SUMMARY_FILE`, `CHECKSUM_FILE` — output paths

## Usage

```bash
./mirror.sh
