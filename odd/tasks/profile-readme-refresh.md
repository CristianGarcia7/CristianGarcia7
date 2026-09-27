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
- [ ] R2 Fix stats: replace the broken public instance with a reliable source (candidate: self-generated SVGs committed by a scheduled GitHub Action; research current action options before choosing). Route: inline or delegated depending on file count.
- [ ] R3 Refresh content: headline "Backend Developer", about table (OMC Production, Ing. Software, Bogotá, AI/RAG), stack (add Docker/CI/CD/LangChain as in CV), projects table (add WordPress RAG as private/production entry, portfolio row → new site/repo), fix links (typing SVG host, blog→portfolio, LinkedIn pending owner). Route: inline (1 file).
- [ ] R4 Full check: checker GREEN, render preview via `gh api markdown`. Route: inline.

## Open decisions (owner)
- Contact email: `criatiangarcia637@gmail.com` (CV + current README) vs `cristiangarcia637@gmail.com` (old WordPress).
- LinkedIn slug correctness.
- Portfolio link target until the new site is deployed.

## Progress / Evidence
- 2026-09-27: cloned to `/home/cristian/Dev/CristianGarcia7`, branch `feat/profile-readme-refresh` from `28c3cec`. URL probe results recorded under Problem.
- R1 done: first run falsely passed (rg not on script PATH → 0 URLs extracted); fixed with portable grep/sed + a guard that fails on 0 URLs. RED observed: 2 FAIL (both github-readme-stats.vercel.app, 503 text/plain), 34 OK, 1 SKIP (LinkedIn). Commit: see `test(readme)` in git log.
- Engram mirror `odd/profile-readme-refresh/tasks`: PENDING (same `ambiguous_project` issue as portfolio-v2).

## Next step
R2 (research a reliable stats source).
