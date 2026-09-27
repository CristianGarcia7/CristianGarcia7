#!/usr/bin/env bash
# Offline, deterministic regression test for scripts/check-readme.sh.
#
# Runs the checker in dry-run mode (no network) against a fixture README
# that exercises every extractor category the checker understands:
#   - HTML <img src> (remote)
#   - markdown image (remote)
#   - HTML <a href> (remote)
#   - markdown link (remote)
#   - a nested badge [![alt](img)](href) — both the image and the outer href
#   - a relative image that exists
#   - a relative image that is missing (must FAIL)
#   - a non-http(s) URL scheme (must FAIL)
#   - a LinkedIn URL (host-blocked automated checks -> SKIP, not FAIL)
#
# Asserts the exact classification output (kind<TAB>url per extracted
# entry, in the checker's stable sort order) and the exit code.
set -uo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
checker="$repo_root/scripts/check-readme.sh"
fixture="$script_dir/fixture/README.md"

fail=0

expected=$(cat <<'EOF'
img-local-missing	assets/missing.svg
img-local-ok	assets/ok.svg
img-remote	https://example.com/pic.png
img-remote	https://example.com/pic2.png
img-remote	https://img.shields.io/badge/-ok-green
link-scheme-fail	file:///etc/hosts
link-remote	https://example.com/page
link-remote	https://example.com/page2
link-remote	https://example.com/target
link-skip-host	https://www.linkedin.com/in/someone
EOF
)

actual=$(CHECK_README_DRY_RUN=1 bash "$checker" "$fixture" 2>&1)
exit_code=$?

echo "--- actual dry-run output ---"
printf '%s\n' "$actual"
echo "--- exit code: $exit_code ---"

# 1. Exact classification set (order-independent isn't good enough: the
#    checker's sort order is a documented contract of the extractors).
classification_lines=$(printf '%s\n' "$actual" | grep -E $'^[a-z-]+\t')
if [[ "$classification_lines" == "$expected" ]]; then
  echo "PASS: classification lines match expected fixture set"
else
  echo "FAIL: classification lines do not match"
  echo "--- expected ---"
  printf '%s\n' "$expected"
  echo "--- got ---"
  printf '%s\n' "$classification_lines"
  fail=1
fi

# 2. Separate, explicit assertion: a missing relative image is classified
#    as a failure.
if printf '%s\n' "$actual" | grep -qF $'img-local-missing\tassets/missing.svg'; then
  echo "PASS: missing relative image classified as img-local-missing"
else
  echo "FAIL: missing relative image was not classified as img-local-missing"
  fail=1
fi

# 3. A missing relative image (and the disallowed file:// scheme) must
#    make the whole run fail with a non-zero exit code.
if [[ "$exit_code" -ne 0 ]]; then
  echo "PASS: checker exited non-zero ($exit_code) on fixture with failures"
else
  echo "FAIL: checker exited 0 despite a missing relative image"
  fail=1
fi

if [[ "$fail" -eq 0 ]]; then
  echo "ALL TESTS PASSED"
  exit 0
else
  echo "TESTS FAILED"
  exit 1
fi
