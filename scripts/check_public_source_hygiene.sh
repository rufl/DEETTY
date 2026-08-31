#!/usr/bin/env sh
set -eu
export LC_ALL=C

# This gate inspects existing tracked and not-ignored candidate source. Full-
# history secret scanning remains a separate maintainer action because ordinary
# contributors should not need extra security tooling for the bounded gate.
tracked_files=$(
  git ls-files --cached --others --exclude-standard |
    while IFS= read -r path; do
      if [ -e "$path" ]; then printf '%s\n' "$path"; fi
    done
)

for required in LICENSE THIRD_PARTY_NOTICES.md CONTRIBUTING.md SECURITY.md \
  CODE_OF_CONDUCT.md SUPPORT.md; do
  test -s "$required" || {
    echo "public_source_hygiene missing_required_file=$required" >&2
    exit 1
  }
done

if printf '%s\n' "$tracked_files" | grep -E \
  '(^|/)(\.zig-cache|zig-out|dist)(/|$)|\.(so(\.[0-9]+)*|dll|exe|a|o|obj|zip|tar\.gz|tar\.xz|tar\.zst)$' \
  >/dev/null; then
  echo 'public_source_hygiene generated_or_binary_artifact_tracked=true' >&2
  exit 1
fi

if printf '%s\n' "$tracked_files" | grep -E \
  '(^|/)(\.env($|\.)|id_(rsa|dsa|ecdsa|ed25519)($|\.)|credentials($|\.)|secrets?($|\.)|core($|\.)|[^/]+\.(key|pem|p12|pfx|kdbx|sqlite|db|dump))$' \
  >/dev/null; then
  echo 'public_source_hygiene sensitive_filename_tracked=true' >&2
  exit 1
fi

if git grep -I -n -E '^(<<<<<<< |=======|>>>>>>> )' -- . \
  ':!vendor/**' ':!src/terminal/fixtures/**' >/dev/null; then
  echo 'public_source_hygiene merge_marker=true' >&2
  exit 1
fi

# GitHub actions are third-party release inputs. Pinning immutable revisions
# prevents an upstream tag move from changing CI or packaging behavior.
if grep -R -h -E '^[[:space:]]*uses:' .github/workflows 2>/dev/null |
  grep -E -v 'uses:[[:space:]]+\./|@[0-9a-f]{40}([[:space:]]|$)' >/dev/null; then
  echo 'public_source_hygiene unpinned_github_action=true' >&2
  exit 1
fi

printf '%s\n' \
  'public_source_hygiene required_files=true generated_artifacts=false binary_artifacts=false sensitive_filenames=false merge_markers=false actions_pinned=true'
