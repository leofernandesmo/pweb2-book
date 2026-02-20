
# 📘 My Open Book — README

Welcome to the repository for **My Open Book**, an open educational resource built using **MkDocs** and **Material for MkDocs**.

This README will guide you through:

1. How to **fork** this repository
2. How to **clone** it to your computer
3. How to **install** the required tools
4. How to **build and preview** the book locally
5. (Optional) How to **deploy** the website using GitHub Pages



## 🔧 Using this repository as a template

1. Click **Use this template** on GitHub.
2. Choose a name for your new repository, e.g. `my-web-programming-book`.
3. After creating the repo, edit:

   - `mkdocs.yml`:
     - `site_name`
     - `site_description`
     - `site_url` and `repo_url`
   - `docs/index.md`, `docs/cover.md`, `docs/title-page.md`, etc.:
     - Replace placeholder title, author, institution, year, etc.

4. Enable GitHub Pages under **Settings → Pages**:
   - Source: `Deploy from a branch`
   - Branch: `gh-pages`, folder `/`


### Or you can create your own open-book template...

---

# ⭐ 1. Forking the Repository

If you want to contribute or keep your own copy:

1. Open the repository page on GitHub.
2. Click the **“Fork”** button (top right).
3. Choose your GitHub account as the destination.
4. GitHub will create a new repository under your profile, e.g.:

```
https://github.com/<your-username>/my-open-book
```

This is now **your own** version.

---

# ⭐ 2. Cloning the Repository

After forking, clone **your fork** to your local machine:

```bash
git clone https://github.com/<your-username>/my-open-book.git
```

Then:

```bash
cd my-open-book
```

To verify the folder contents:

```bash
ls -R
```

You should see:

```
mkdocs.yml
docs/
.github/
...
```

---

# ⭐ 3. Installing Dependencies

This project requires **Python 3.10+**.

### Install MkDocs + Material theme:

```bash
pip install mkdocs-material
```

### Install PDF printing plugin:

```bash
pip install mkdocs-print-site-plugin
```

(Optional, but recommended)

---

# ⭐ 4. Previewing the Book Locally

To start a local development server:

```bash
mkdocs serve
```

Then open your browser and go to:

```
http://127.0.0.1:8000
```

Every time you edit files in `docs/`, the site automatically reloads.

---

# ⭐ 5. Building the Static Site

To build the final static HTML version:

```bash
mkdocs build
```

This creates a folder:

```
site/
```

This folder contains the full HTML site that can be deployed anywhere.

---

# ⭐ 6. Deploying to GitHub Pages (Owner Only)

If **you own** the repository (not contributors or students):

Deploy with:

```bash
mkdocs gh-deploy
```

or let **GitHub Actions auto-deploy** using the provided workflow.

After deployment, the site will be available at:

```
https://<your-username>.github.io/my-open-book/
```

If you're a **student who forked the project**, your site will appear under:

```
https://<your-username>.github.io/<your-fork-name>/
```

---

# ⭐ 7. Repository Structure (Quick Overview)

```
my-open-book/
├── mkdocs.yml             # MkDocs configuration
├── docs/                  # All book pages live here
│   ├── index.md
│   ├── cover.md
│   ├── title-page.md
│   ├── preface.md
│   ├── back-cover.md
│   ├── chapters/
│   ├── figures/
│   ├── media/
│   └── assets/
└── .github/workflows/     # Auto-deployment to GitHub Pages
```

---

# ⭐ 8. Contributing

If you wish to contribute:

1. Fork the repo

2. Create a new branch:

   ```bash
   git checkout -b my-new-section
   ```

3. Commit your changes:

   ```bash
   git add .
   git commit -m "Add new section/chapter"
   ```

4. Push the branch:

   ```bash
   git push origin my-new-section
   ```

5. Open a **Pull Request** on GitHub.

---

# ⭐ 9. Useful Commands (Cheat Sheet)

| Task               | Command                                                |
| ------------------ | ------------------------------------------------------ |
| Start local server | `mkdocs serve`                                         |
| Build site         | `mkdocs build`                                         |
| Deploy to Pages    | `mkdocs gh-deploy`                                     |
| Install deps       | `pip install mkdocs-material mkdocs-print-site-plugin` |

---


