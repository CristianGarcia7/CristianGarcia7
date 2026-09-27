#!/usr/bin/env bash
# Validates every URL referenced by README.md.
# - Images (<img src> and ![](...)) must answer 2xx with an image/* content type.
# - Links (<a href> and [](...)) must answer 2xx/3xx after redirects.
# - Hosts that block automated clients (LinkedIn) are reported as SKIP, not FAIL.
# Exits non-zero when any URL fails.
set -uo pipefail

readme="${1:-README.md}"
bot_blocked_hosts='linkedin\.com'
failures=0

check() {
  local kind="$1" url="$2"
  if [[ "$url" =~ $bot_blocked_hosts ]]; then
    printf 'SKIP  %-5s %s (host blocks automated checks; verify manually)\n' "$kind" "$url"
    return
  fi

  local out status ctype
  out=$(curl -sSL -o /dev/null -m 20 -A 'readme-check' -w '%{http_code} %{content_type}' "$url" 2>/dev/null)
  status="${out%% *}"
  ctype="${out#* }"

  local ok=1
  [[ "$status" =~ ^[23] ]] || ok=0
  if [[ "$kind" == "img" && "$ctype" != image/* ]]; then ok=0; fi

  if (( ok )); then
    printf 'OK    %-5s %s %s\n' "$kind" "$status" "$url"
  else
    printf 'FAIL  %-5s %s [%s] %s\n' "$kind" "$status" "$ctype" "$url"
    failures=$((failures + 1))
  fi
}

# Plain grep/sed on purpose: the script must run on any machine or CI runner.
images=$(
  { grep -oE '<img[^>]*src="[^"]+"' "$readme" | sed -E 's/.*src="([^"]+)".*/\1/'
    grep -oE '!\[[^]]*\]\(https?://[^) ]+\)' "$readme" | sed -E 's/.*\((.*)\)$/\1/'; } | sort -u
)
# HTML links and markdown links (non-image), excluding mailto.
links=$(
  { grep -oE '<a[^>]*href="https?://[^"]+"' "$readme" | sed -E 's/.*href="([^"]+)".*/\1/'
    grep -oE '(^|[^!])\[[^]]*\]\(https?://[^) ]+\)' "$readme" | sed -E 's/.*\]\((.*)\)$/\1/'; } | sort -u
)

if [[ -z "$images$links" ]]; then
  echo "README check failed: no URLs found in $readme (extractor broken?)."
  exit 1
fi

while read -r url; do [[ -n "$url" ]] && check img "$url"; done <<< "$images"
while read -r url; do [[ -n "$url" ]] && check link "$url"; done <<< "$links"

if (( failures > 0 )); then
  echo "README check failed: $failures URL(s) broken."
  exit 1
fi
echo "README check passed."
