<!--
SPDX-FileCopyrightText: 2026 CodeNib Contributors

SPDX-License-Identifier: Apache-2.0
-->

# CodeNib Wiki action

Publish a source-linked Wiki of your repository on GitHub Pages. The Wiki opens
as a map of the code's parts; every page explains what the code does and links
each claim to the exact lines. The code graph comes from compiler-grade
indexers, not from a model's guess.

```yaml
name: CodeNib Wiki
on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  wiki:
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.wiki.outputs.page-url }}
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0
      - uses: sysevol-ai/wiki-action@v1
        id: wiki
        with:
          api-key: ${{ secrets.OPENROUTER_API_KEY }}
```

1. In **Settings > Pages**, choose **GitHub Actions** as the source. The Wiki
   then becomes the repository's whole Pages site: it replaces a site already
   deployed there, and a site served from a branch such as `gh-pages` stops
   being served. To keep an existing site, use a repository without one, or
   [build the Wiki without deploying it](https://docs.codenib.ai/github_pages/#build-without-deployment)
   and host the output elsewhere.
2. Add an [OpenRouter](https://openrouter.ai/) key as the Actions secret
   `OPENROUTER_API_KEY`, with a spending limit on the key.
3. Push. The first run writes every page; later pushes rewrite only the pages
   whose source files changed. Run the workflow with `full-rebuild: true` to
   pick up new parts of the code.

The Wiki is always written by a model, so `api-key` is required. Without it
the run stops before it indexes anything and says how to add one. Earlier
releases also took `wiki: index` for pages without a model; that mode was
removed, and a workflow that still sets it stops with a message.

Pages that fail their quality checks are left out and written again on the
next push. If the Overview fails, or fewer than 80% of the pages pass, the run
fails and nothing is deployed; the Wiki from the last successful run stays.

Run `codenib pages badge` in the repository for a README badge that links to
the published Wiki.

## Source

This repository is the action's source. Each release installs CodeNib from
the commit `action.yml` pins. The
[GitHub Pages guide](https://docs.codenib.ai/github_pages/) covers the options
in full. Report problems in
[CodeNib's issues](https://github.com/sysevol-ai/CodeNib/issues).
