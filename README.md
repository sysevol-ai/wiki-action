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
   being served. To keep an existing site, publish the Wiki into a folder of
   it instead; see [Keep an existing site](#keep-an-existing-site).
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

## Keep an existing site

A repository has one Pages site. To publish the Wiki next to a site you
already have, put it in a folder of that site, `wiki/` by default, with
`deploy`:

| `deploy` | Where the Wiki goes | Who deploys |
| --- | --- | --- |
| `pages` (default) | The whole Pages site | This action |
| `branch` | A folder of the branch Pages serves, such as `gh-pages` | This action pushes; Pages serves the branch |
| `none` | A folder on the runner, returned as `site-path` | Your workflow |

`path` names the folder, such as `docs/code`. Links in the Wiki include it,
so the Wiki only works at that address.

**Your site is served from a branch.** Keep **Deploy from a branch** under
**Settings > Pages**, and let the action commit the Wiki into the branch:

```yaml
permissions:
  contents: write
  pages: read

jobs:
  wiki:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0
      - uses: sysevol-ai/wiki-action@v1
        with:
          api-key: ${{ secrets.OPENROUTER_API_KEY }}
          deploy: branch
```

The Wiki appears at `https://<owner>.github.io/<repo>/wiki/`. The action only
replaces a folder it wrote before; it stops if the folder holds anything else.
It also stops if Pages builds the branch with Jekyll, which would leave out
some of the Wiki's files; an empty `.nojekyll` file at the branch root turns
Jekyll off. A branch that does not exist yet is created.

**Your site is deployed by its own workflow.** Build the Wiki in your deploy
job, which keeps its permissions and environment, and deploy both together:

```yaml
      - run: npm run build # your site, into dist/
      - uses: sysevol-ai/wiki-action@v1
        id: wiki
        with:
          api-key: ${{ secrets.OPENROUTER_API_KEY }}
          deploy: none
      - run: cp -R "${{ steps.wiki.outputs.site-path }}" dist/wiki
      - uses: actions/upload-pages-artifact@v5
        with:
          path: dist
      - uses: actions/deploy-pages@v5
```

The address, custom domains included, comes from the repository's Pages
settings. To serve the Wiki from another host, set `base-path` to the full URL
path it is served from, such as `/wiki`.

## Source

This repository is the action's source. Each release installs CodeNib from
the commit `action.yml` pins. The
[GitHub Pages guide](https://docs.codenib.ai/github_pages/) covers the options
in full. Report problems in
[CodeNib's issues](https://github.com/sysevol-ai/CodeNib/issues).
