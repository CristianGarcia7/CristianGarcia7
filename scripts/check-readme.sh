#!/usr/bin/env bash
# Validates every URL and local asset path referenced by README.md.
# - Images (<img src> and ![](...), including the image half of a nested
#   [![alt](img)](href) badge) must resolve: remote http(s) images require a
#   final 2xx status (after following redirects) and an image/* content
#   type; local relative paths must exist as files and have an image
#   extension (.svg/.png/.jpg/.jpeg/.gif/.webp).
# - Links (<a href>, [](...), and the outer href of a
#   [![alt](img)](href) badge) must resolve: remote http(s) links also
#   require a final 2xx status (after following redirects, same contract as
#   images -- a redirect that only ever lands on a 3xx is a failure); local
#   relative paths must exist as files.
# - Only http(s) URLs and relative paths are accepted. Any other URL scheme
#   (file:, data:, javascript:, ...) is a FAIL. mailto: links are not
#   extracted at all (nothing meaningful to check).
# - Hosts that block automated clients (LinkedIn) are reported as SKIP, not
#   FAIL, matched against the URL's hostname only (not the whole URL).
# - Transient remote failures (no response / 000, or 5xx) are retried up to
#   2 extra times with a short backoff before being reported as FAIL; a URL
#   that stays down still fails.
# Exits non-zero when any URL/path fails.
#
# Set CHECK_README_DRY_RUN=1 to skip every network call: each extracted
# entry is classified and printed instead as "<classification><TAB><value>"
# (local-file checks still run for real in dry-run mode -- they are offline
# anyway -- so a missing relative asset still fails the run).
set -uo pipefail

readme="${1:-README.md}"
readme_dir=$(dirname -- "$readme")
bot_blocked_hosts='(^|\.)linkedin\.com$'
image_ext_re='\.(svg|png|jpg|jpeg|gif|webp)$'
scheme_re='^[A-Za-z][A-Za-z0-9+.-]*:'
http_re='^https?://'
dry_run="${CHECK_README_DRY_RUN:-0}"
failures=0

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Extract just the host from an http(s) URL: drop scheme, userinfo,
# path/query/fragment and port.
host_of() {
  printf '%s' "$1" | sed -E 's#^[A-Za-z]+://([^@/]*@)?##; s#[/?#].*##; s#:.*##'
}

is_bot_blocked() {
  local host
  host=$(lower "$(host_of "$1")")
  [[ "$host" =~ $bot_blocked_hosts ]]
}

is_local_image_ok() {
  local kind="$1" raw="$2" path
  path="$readme_dir/$raw"
  [[ -f "$path" ]] || return 1
  if [[ "$kind" == "img" ]]; then
    local lower_raw
    lower_raw=$(lower "$raw")
    [[ "$lower_raw" =~ $image_ext_re ]] || return 1
  fi
  return 0
}

check_remote() {
  local kind="$1" url="$2"
  if is_bot_blocked "$url"; then
    printf 'SKIP  %-5s %s (host blocks automated checks; verify manually)\n' "$kind" "$url"
    return
  fi

  local attempt=0 max_attempts=3 status='000' ctype='' curl_err='' err_file out
  err_file=$(mktemp)
  while (( attempt < max_attempts )); do
    attempt=$((attempt + 1))
    out=$(curl -sSL -o /dev/null -m 20 -A 'readme-check' \
          --proto '=http,https' --proto-redir '=http,https' \
          -w '%{http_code} %{content_type}' \
          -- "$url" 2>"$err_file")
    status="${out%% *}"
    ctype="${out#* }"
    curl_err=$(tr -d '\n' <"$err_file")
    [[ "$status" =~ ^2 ]] && break
    if [[ ( "$status" == "000" || "$status" =~ ^5 ) && "$attempt" -lt "$max_attempts" ]]; then
      sleep "$attempt"
      : >"$err_file"
      continue
    fi
    break
  done
  rm -f "$err_file"

  local ok=1
  [[ "$status" =~ ^2 ]] || ok=0
  if [[ "$kind" == "img" && "$ctype" != image/* ]]; then ok=0; fi

  if (( ok )); then
    printf 'OK    %-5s %s %s\n' "$kind" "$status" "$url"
  else
    if [[ "$status" == "000" ]]; then
      printf 'FAIL  %-5s %s [%s] %s - %s\n' "$kind" "$status" "$ctype" "$url" "${curl_err:-curl request failed}"
    else
      printf 'FAIL  %-5s %s [%s] %s\n' "$kind" "$status" "$ctype" "$url"
    fi
    failures=$((failures + 1))
  fi
}

check_local() {
  local kind="$1" raw="$2" path
  path="$readme_dir/$raw"
  if [[ ! -f "$path" ]]; then
    printf 'FAIL  %-5s local file not found: %s (resolved: %s)\n' "$kind" "$raw" "$path"
    failures=$((failures + 1))
    return
  fi
  if [[ "$kind" == "img" ]]; then
    local lower_raw
    lower_raw=$(lower "$raw")
    if [[ ! "$lower_raw" =~ $image_ext_re ]]; then
      printf 'FAIL  %-5s local image has unsupported extension: %s\n' "$kind" "$raw"
      failures=$((failures + 1))
      return
    fi
  fi
  printf 'OK    %-5s local %s\n' "$kind" "$raw"
}

# Dry-run classification: same routing as the real checker, but never
# touches the network. Local-file checks are real (they are offline).
classify_dry_run() {
  local kind="$1" url="$2"
  if [[ "$url" =~ $http_re ]]; then
    if is_bot_blocked "$url"; then
      printf '%s-skip-host\t%s\n' "$kind" "$url"
    else
      printf '%s-remote\t%s\n' "$kind" "$url"
    fi
    return
  fi
  if [[ "$url" =~ $scheme_re ]]; then
    printf '%s-scheme-fail\t%s\n' "$kind" "$url"
    return
  fi
  if [[ ! -f "$readme_dir/$url" ]]; then
    printf '%s-local-missing\t%s\n' "$kind" "$url"
    return
  fi
  if [[ "$kind" == "img" ]]; then
    local lower_url
    lower_url=$(lower "$url")
    if [[ ! "$lower_url" =~ $image_ext_re ]]; then
      printf '%s-local-badext\t%s\n' "$kind" "$url"
      return
    fi
  fi
  printf '%s-local-ok\t%s\n' "$kind" "$url"
}

dispatch() {
  local kind="$1" url="$2"
  [[ -z "$url" ]] && return
  [[ "$url" =~ ^mailto: ]] && return

  if (( dry_run )); then
    local cls
    cls=$(classify_dry_run "$kind" "$url")
    printf '%s\n' "$cls"
    case "$cls" in
      *-local-missing*|*-local-badext*|*-scheme-fail*) failures=$((failures + 1)) ;;
    esac
    return
  fi

  if [[ "$url" =~ $http_re ]]; then
    check_remote "$kind" "$url"
  elif [[ "$url" =~ $scheme_re ]]; then
    printf 'FAIL  %-5s disallowed URL scheme: %s\n' "$kind" "$url"
    failures=$((failures + 1))
  else
    check_local "$kind" "$url"
  fi
}

# Plain grep/sed on purpose: the script must run on any machine or CI
# runner, no ripgrep required. URL/path values are scheme-agnostic here;
# classification (remote / relative-local / disallowed scheme) happens per
# entry in dispatch above.

# Images: <img src="..."> and markdown ![alt](url). The markdown pattern
# also matches the image half of a [![alt](img)](href) badge correctly on
# its own, because "![alt]" always stops at the first "]".
images=$(
  { grep -oE '<img[^>]*src="[^"]+"' "$readme" | sed -E 's/.*src="([^"]+)".*/\1/'
    grep -oE '!\[[^]]*\]\([^) ]+\)' "$readme" | sed -E 's/.*\((.*)\)$/\1/'; } | LC_ALL=C sort -u
)

# Nested badges [![alt](img)](href): the outer href is otherwise invisible
# to the plain-link extractor below, because "\[[^]]*\]" stops at the first
# "]" -- the inner alt text's closing bracket -- and then matches the
# image's own parens instead of the outer ones. Pull the href out
# explicitly here, then strip the whole badge from a working copy before
# extracting plain links, so the plain extractor never sees the leftover
# image parens.
badge_pattern='\[!\[[^]]*\]\([^) ]+\)\]\([^) ]+\)'
badge_links=$(grep -oE "$badge_pattern" "$readme" | sed -E 's/.*\]\(([^) ]+)\)$/\1/')
stripped=$(sed -E "s#${badge_pattern}##g" "$readme")

# Links: <a href="...">, plain (non-image) markdown links from the
# badge-stripped text, and the badge hrefs collected above.
links=$(
  { grep -oE '<a[^>]*href="[^"]+"' "$readme" | sed -E 's/.*href="([^"]+)".*/\1/'
    grep -oE '(^|[^!])\[[^]]*\]\([^) ]+\)' <<< "$stripped" | sed -E 's/.*\]\(([^) ]+)\)$/\1/'
    printf '%s\n' "$badge_links"; } | LC_ALL=C sort -u
)

if [[ -z "$images$links" ]]; then
  echo "README check failed: no URLs found in $readme (extractor broken?)."
  exit 1
fi

while IFS= read -r url; do dispatch img "$url"; done <<< "$images"
while IFS= read -r url; do dispatch link "$url"; done <<< "$links"

if (( failures > 0 )); then
  if (( dry_run )); then
    echo "README check (dry run) failed: $failures entries classified as broken."
  else
    echo "README check failed: $failures URL(s)/path(s) broken."
  fi
  exit 1
fi
echo "README check passed."
