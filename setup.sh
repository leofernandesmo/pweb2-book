#!/usr/bin/env bash

# -------------------------------------------------------
# Create base folder for your book
# -------------------------------------------------------
mkdir -p pweb2-book
cd pweb2-book

# -------------------------------------------------------
# Create MkDocs main config file
# -------------------------------------------------------
cat > mkdocs.yml << 'EOF'
site_name: PWeb2 Book
site_description: "Um material aberto para os estudantes"
site_url: "https://leofernandesmo.github.io/pweb2-book/"
repo_url: "https://github.com/leofernandesmo/pweb2-book"
repo_name: "GitHub"

theme:
  name: material
  language: pt
  features:
    - navigation.tabs
    - navigation.top
    - navigation.sections
    - navigation.indexes
    - content.code.copy
    - content.action.edit
    - content.action.view
    - toc.integrate
  palette:
    - scheme: default
      primary: indigo
      accent: indigo
    - scheme: slate
      primary: indigo
      accent: indigo
      toggle:
        icon: material/weather-night
        name: Switch to dark mode

extra:
  social:
    - icon: fontawesome/brands/github
      link: "https://github.com/YOUR-USERNAME"

markdown_extensions:
  - admonition
  - footnotes
  - toc:
      permalink: true
  - codehilite:
      guess_lang: false
  - pymdownx.superfences
  - pymdownx.tabbed:
      alternate_style: true
  - pymdownx.details
  - pymdownx.highlight
  - pymdownx.emoji
  - pymdownx.tasklist:
      custom_checkbox: true

plugins:
  - search
  - print-site:
      add_to_navigation: true
      print_page_title: "Print / Save PDF"
      add_print_button: true

extra_css:
  - assets/extra.css

nav:
  - Home: index.md
  - Cover: cover.md
  - Title Page: title-page.md
  - Preface: preface.md
  - Chapters:
      - "1. Introduction": chapters/01-introduction.md
      - "2. First Steps": chapters/02-first-steps.md
      - "Appendix": chapters/99-appendix.md
  - Back Cover: back-cover.md
EOF

# -------------------------------------------------------
# Create docs/ structure
# -------------------------------------------------------
mkdir -p docs/chapters
mkdir -p docs/figures
mkdir -p docs/media
mkdir -p docs/assets

# -------------------------------------------------------
# Create Markdown files
# -------------------------------------------------------

cat > docs/index.md << 'EOF'
# My Open Book Title

Welcome to the open version of **My Open Book**.

This site works on:

- 📱 Smartphones  
- 💻 Desktop browsers  
- 🧾 PDF via **Print / Save PDF**

Use the navigation menu to browse the book.
EOF

cat > docs/cover.md << 'EOF'
# 📘 My Open Book Title

**Subtitle:** A Gentle Introduction to [Topic]

**Author:** Your Name  

> _“A short inspiring quote or tagline for the book.”_
EOF

cat > docs/title-page.md << 'EOF'
# My Open Book Title

_A Gentle Introduction to [Topic]_

**Author:**  
Leo Fernandes  
IFAL

**Edition:** 1st Edition  
**Year:** 2025  
EOF

cat > docs/preface.md << 'EOF'
# Preface

This book is designed to be:

- Open
- Living
- Multimodal

Start reading the first chapter from the menu on the left.
EOF

cat > docs/back-cover.md << 'EOF'
# Back Cover

Thank you for reading **My Open Book**.  
Feel free to contribute on GitHub!
EOF

# -------------------------------------------------------
# Create example chapters
# -------------------------------------------------------

cat > docs/chapters/01-introduction.md << 'EOF'
# 1. Introduction

Welcome to the first chapter of this open book.
EOF

cat > docs/chapters/02-first-steps.md << 'EOF'
# 2. First Steps

This chapter continues your learning journey.
EOF

cat > docs/chapters/99-appendix.md << 'EOF'
# Appendix

Reference tables and supporting materials go here.
EOF

# -------------------------------------------------------
# Create placeholder image, audio, and extra CSS
# -------------------------------------------------------

# placeholder PNG (1x1 transparent)
printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc`\x00\x00\x00\x02\x00\x01\xe2!\xbc3\x00\x00\x00\x00IEND\xaeB`\x82' \
  > docs/figures/example-diagram.png

# placeholder MP3 (silence)
echo "Placeholder audio file" > docs/media/example-audio.mp3

# Create custom extra CSS
cat > docs/assets/extra.css << 'EOF'
/* Custom extra CSS for PDF printing */

.md-main__inner {
  max-width: 900px;
}

@media print {
  pre, code {
    font-size: 0.85em;
  }

  .md-header,
  .md-sidebar,
  .md-footer {
    display: none !important;
  }

  .md-main__inner {
    margin: 0;
    padding: 0;
    max-width: 100%;
  }

  body {
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }
}
EOF

# -------------------------------------------------------
# GitHub Actions workflow
# -------------------------------------------------------
mkdir -p .github/workflows

cat > .github/workflows/deploy.yml << 'EOF'
name: Deploy MkDocs site

on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  build-deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install dependencies
        run: |
          pip install mkdocs-material mkdocs-print-site-plugin

      - name: Build site
        run: mkdocs build --strict

      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./site
EOF

# -------------------------------------------------------
# Finish
# -------------------------------------------------------

echo "✔ Project initialized successfully!"
echo "Next steps:"
echo "1. cd my-open-book"
echo "2. pip install mkdocs-material mkdocs-print-site-plugin"
echo "3. mkdocs serve   (preview locally)"
echo "4. git init && git add . && git commit -m 'Initial commit'"
echo "5. Push to GitHub and enable GitHub Pages"
