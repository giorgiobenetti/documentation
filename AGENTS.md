# AGENTS.md

## Cursor Cloud specific instructions

This is the npm Documentation site (docs.npmjs.com) — a Gatsby 5 static site rendering MDX content. It is an npm workspaces monorepo with one workspace (`cli/`).

### Key commands

| Action | Command |
|--------|---------|
| Install deps | `npm install` (from repo root; respects `legacy-peer-deps` in `.npmrc`) |
| Dev server | `npm run develop` (serves at `localhost:8000`) |
| Lint (ESLint) | `npx eslint "**/*.{js,mjs,mdx}"` |
| Tests (root) | `npx jest` |
| Tests (cli workspace) | `npx tap` (run from `cli/` directory) |
| Build | `npm run build` |

### Non-obvious caveats

- **Node.js >= 22 required** (per `.nvmrc` and `engines` field).
- **`postlint` / `template-oss-check` will fail on forks** because it validates the `repository.url` field in `package.json`. The actual ESLint pass is clean; run ESLint directly (`npx eslint`) to verify lint without the template-oss check.
- **`GITHUB_TOKEN` is optional locally** — without it, contributor data on pages falls back to test data. Only required in CI.
- **Speed up dev server** with `GATSBY_CONTENT_IGNORE=cli/v6,cli/v7,cli/v8,cli/v9` to skip older CLI docs (the largest content set). See `CONTRIBUTING.md` for details on `GATSBY_CONTENT_ALLOW` / `GATSBY_CONTENT_IGNORE`.
- The Gatsby dev server's initial build takes ~40–60 seconds even with content filtering. Hot-reload on content changes is instant after that.
- The `cli/` workspace's `npm run build -w cli` fetches docs from GitHub and the npm registry; it is not needed for day-to-day site development unless you are updating CLI content.
