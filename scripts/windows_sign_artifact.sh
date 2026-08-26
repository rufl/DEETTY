#!/usr/bin/env sh
set -eu

export LC_ALL=C
export TZ=UTC

if [ "$#" -ne 4 ]; then
  echo 'usage: windows_sign_artifact.sh KIND UNSIGNED_INPUT SIGNED_OUTPUT VERIFICATION_RECEIPT' >&2
  exit 2
fi
kind=$1
unsigned_input=$2
signed_output=$3
verification_receipt=$4
case "$kind" in
  noctty-exe|nocted-exe|installer) ;;
  *) echo "windows_sign_artifact error=unsupported_kind kind=$kind" >&2; exit 2 ;;
esac
hook=${NOCTTY_WINDOWS_SIGN_HOOK:-}
case "$hook" in
  /*) ;;
  *) echo 'windows_sign_artifact error=sign_hook_must_be_absolute' >&2; exit 1 ;;
esac
test -x "$hook"
test -s "$unsigned_input"
case "$signed_output" in
  /*) ;;
  *) echo 'windows_sign_artifact error=signed_output_must_be_absolute' >&2; exit 1 ;;
esac
case "$verification_receipt" in
  /*) ;;
  *) echo 'windows_sign_artifact error=receipt_must_be_absolute' >&2; exit 1 ;;
esac

test "$unsigned_input" != "$signed_output"
output_dir=$(dirname "$signed_output")
receipt_dir=$(dirname "$verification_receipt")
test -d "$output_dir"
test -d "$receipt_dir"
signed_tmp=$(mktemp "$output_dir/.$(basename "$signed_output").tmp.XXXXXX")
receipt_tmp=$(mktemp "$receipt_dir/.$(basename "$verification_receipt").tmp.XXXXXX")
verify_tmp=$(mktemp "$receipt_dir/.windows-sign-verify.tmp.XXXXXX")
cleanup() {
  rm -f "$signed_tmp" "$receipt_tmp" "$verify_tmp"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
rm -f "$signed_tmp"

unsigned_before=$(sha256sum "$unsigned_input" | awk '{print $1}')
"$hook" sign "$kind" "$unsigned_input" "$signed_tmp"
test -s "$signed_tmp"
signed_digest=$(sha256sum "$signed_tmp" | awk '{print $1}')
test "$unsigned_before" != "$signed_digest"
"$hook" verify "$kind" "$signed_tmp" > "$verify_tmp"
test -s "$verify_tmp"
grep -E '^signer_identity=.+' "$verify_tmp" >/dev/null
grep -E '^certificate_thumbprint=.+' "$verify_tmp" >/dev/null
grep -E '^timestamp_present=(true|false)$' "$verify_tmp" >/dev/null
grep -E '^signing_tool=.+' "$verify_tmp" >/dev/null
unsigned_after=$(sha256sum "$unsigned_input" | awk '{print $1}')
test "$unsigned_before" = "$unsigned_after"

{
  printf 'windows_artifact_signing_verification_version=1\n'
  printf 'kind=%s\n' "$kind"
  printf 'unsigned_sha256=%s\n' "$unsigned_before"
  printf 'signed_sha256=%s\n' "$signed_digest"
  printf 'verification_begin\n'
  cat "$verify_tmp"
  printf 'verification_end\n'
} > "$receipt_tmp"
chmod 0644 "$signed_tmp" "$receipt_tmp"
mv -f "$signed_tmp" "$signed_output"
signed_tmp=
mv -f "$receipt_tmp" "$verification_receipt"
receipt_tmp=

echo "windows_sign_artifact kind=$kind signed_output=$signed_output signed_sha256=$signed_digest"
