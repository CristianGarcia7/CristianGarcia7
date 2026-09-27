# Feature: profile-readme-refresh

## Objective
Bring the GitHub profile README (`CristianGarcia7/CristianGarcia7`) up to date with the current CV and fix its broken widgets.

## Problem / Why
Exploration (2026-09-27) of the live README found:
- **Broken**: both stats cards use the public `github-readme-stats.vercel.app` instance, which answers `503 text/plain` → the images render as broken links (confirmed in the owner's screenshot).
- **Outdated**: headline "Desarrollador Full Stack"; "Tecnólogo ADSO" only (missing Ingeniería de Software, Politécnico Grancolombiano); location Sogamoso (CV: Bogotá D.C.); no mention of OMC Production, NestJS APIs, AI agents in production, the WordPress RAG plugin (hybrid search, SSE, 47 PHPUnit tests), CI/CD on AWS.
- **Stale links**: "Portafolio" row points at the old Vite repo; "Blog" badge points at the outdated WordPress site; typing SVG uses the legacy `readme-typing-svg.herokuapp.com` host (still 200; `readme-typing-svg.demolab.com` also 200).
- **Unverifiable**: LinkedIn slug `cristian-yohani-gracia-rincon-developer` ("gracia" vs "garcia") — LinkedIn blocks automated checks (HTTP 999).
- Working: shields.io badges, komarev visitor counter (200 svg).

## Scope (authorized)
- `README.md` of the profile repo only (+ any workflow/asset needed to replace the broken stats).
- Out of scope: push, PR, merge (owner's decision); portfolio site code (tracked in `portafolio-next/odd/tasks/portfolio-v2.md`).

## Constraints
- Content only from the CV and verified public repos; no invented metrics.
- Copy in neutral professional Spanish (existing README language).
- No third-party personal data (reference contact's phone).
- Every image/link must resolve; replace external widgets that depend on an unreliable free shared instance.

## TDD
- Mode: enabled — source: `~/.claude/CLAUDE.md` (Strict TDD Mode: enabled).
- Runner: none exists in this repo → R1 adds a link/image checker script (`scripts/check-readme.sh`, bash + curl) that exits non-zero on any non-2xx/3xx URL or non-image `<img>` response. RED = current README fails on the stats URLs.

## Delivery
- Forecast: ~150 authored changed lines (< 400) → single slice, strategy `ask-on-risk` (no chain needed).
- RDD: on (decided by default). Assess each work-unit commit.

## Tasks
- [x] R1 Checker: `scripts/check-readme.sh` extracts URLs from README.md and validates status + image content type; observe RED on current README. Route: inline (1 mechanical file).
- [x] R1a Harden checker (from R1 4-lens review): resolve relative repo paths as local files (R3-002, blocks R2); extract outer link of `[![img](src)](href)` badges (R3-001); surface curl error cause (R4-curl-error-suppressed); images and links require final 2xx after -L (R2-image-status-contract-mismatch, R4-final-3xx-accepted); `--proto =http,https` + `--` before URL (R1-001); retry transient 000/5xx (R4-no-retry-transient); match bot-block list on host only (R2/R3-004); guard each extractor category + fixture README with expected URLs as the test (R3-003). Route: inline (checker + fixture test).
- [x] R2 Fix stats: add `.github/workflows/update-readme-cards.yml` using `stats-organization/github-readme-stats-action@v2` (weekly cron + workflow_dispatch, `permissions: contents: write`, built-in GITHUB_TOKEN, public stats only) generating `profile/stats.svg` and `profile/top-langs.svg` (theme tokyonight); commit an initial generated pair so the README renders before the first scheduled run; README embeds `./profile/*.svg`. Depends on R1a (checker must accept local assets). Route: inline (workflow + README lines).
  - Research (read-only worker, parent-verified 2026-09-27): upstream `anuraghazra/github-readme-stats` README declares it no longer maintained and points to `stats-organization/github-stats-extended` or the Action (verified line 36). Action latest release v2.1.0 (2026-09-23, verified); inputs card/options/path/token (verified in action.yml). Public `github-stats-extended.vercel.app` returns 200 svg but is a shared free instance → rejected as primary dependency. `vn7n24fzkq/github-profile-summary-cards` viable but different card types; `lowlighter/metrics` last release 2023 → rejected. `readme-typing-svg.demolab.com` is the current public host (R3).
- [x] R3 Refresh content: headline "Backend Developer", about table (OMC Production, Ing. Software, Bogotá, AI/RAG), stack (add Docker/CI/CD/LangChain as in CV), projects table (add WordPress RAG as private/production entry, portfolio row → new site/repo), fix links (typing SVG host, blog→portfolio, LinkedIn pending owner). Route: inline (1 file).
- [x] R4 Full check: checker GREEN, render preview via `gh api markdown`. Route: inline.

## Open decisions (owner)
- ~~Contact email~~ RESOLVED 2026-09-27: owner confirmed `criatiangarcia637@gmail.com` (current README already correct).
- ~~LinkedIn slug~~ RESOLVED 2026-09-27: owner changed it to `https://www.linkedin.com/in/cristian-garcia-developer/` (old `...-gracia-rincon-developer` is stale) → R3 updates badge link.
- Portfolio link target until the new site is deployed.

## Progress / Evidence
- 2026-09-27: cloned to `/home/cristian/Dev/CristianGarcia7`, branch `feat/profile-readme-refresh` from `28c3cec`. URL probe results recorded under Problem.
- R1 done: first run falsely passed (rg not on script PATH → 0 URLs extracted); fixed with portable grep/sed + a guard that fails on 0 URLs. RED observed: 2 FAIL (both github-readme-stats.vercel.app, 503 text/plain), 34 OK, 1 SKIP (LinkedIn). Commit `4168a35`. RDD: high (executable shell) → user granted 4-lens review, APPROVED with 4 WARNING / 7 SUGGESTION advisories → R1a; acknowledged (boundary → `4168a35`).
- Engram mirror `odd/profile-readme-refresh/tasks`: PENDING (same `ambiguous_project` issue as portfolio-v2).

- R1a done (delegated): commit `9f12812`; fixture test RED→GREEN (parent re-ran: ALL TESTS PASSED); real README still fails only on the 2 stats images; shellcheck not installed. RDD assess base `7712463`: HIGH (shell) → review due, NOT started (session usage limit, 2026-09-27).

- R1a review (lineage review-f1e7e920502b7293, 4 lenses, user granted): `correction_required` — CRITICAL R3-anchor-links-fail (anchors, ?query/#fragment and directory links misreported as missing). Correction plan 45 lines; correction commit `237b43e` (47 changed lines, 2 over plan; RED 4 misclassified → GREEN ALL TESTS PASSED; real README still only the 2 stats FAILs). Re-query STATUS → terminal stop `captured_artifacts_unverifiable` (review lifecycle ended without approval; per contract: maintainer inspection or clone-scope disable).

- R2/R3/R4 done (delegated writer, owner asked for delegation): R2 `7b3b64e` (workflow + bootstrap SVGs from github-stats-extended, verified 200 svg); R3 `a84c233` (README content per CV, LinkedIn new URL, blog badge removed, typing SVG on demolab). R4: fixture ALL TESTS PASSED; real README 39 OK / 1 SKIP (LinkedIn) / 0 FAIL (parent re-verified). RDD assess base `237b43e`: HIGH (workflow) → user granted 4-lens review → APPROVED (1 WARNING, 6 SUGGESTION), acknowledged.
- Follow-ups (advisory, not blocking): pin actions to commit SHAs (WARNING R1-001); concurrency group + `git pull --rebase` before push (R4-001/R3-push-race); shared env for username/theme (R2-001); generated-file comment near images (R2-003); validate generated SVG before commit (R3-token-scope).
- Delivery: owner asked to push + merge after R2/R3 (2026-09-27).

## Next step
Follow-ups above (new feature or later tasks).
