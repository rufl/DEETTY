#!/usr/bin/env sh
set -eu

export LC_ALL=C
set -f

if [ "$#" -ne 5 ]; then
  echo "usage: $0 <library-sources> <stage> <library-inventory> <package-inventory> <license-files>" >&2
  exit 2
fi

library_sources=$1
stage=$2
library_inventory=$3
package_inventory=$4
license_files=$5

test -s "$library_sources"
test -d "$stage"

package_backend=${NOCTTY_PACKAGE_BACKEND:-}
if [ -z "$package_backend" ]; then
  if command -v pacman >/dev/null 2>&1; then
    package_backend=arch
  elif command -v dpkg-query >/dev/null 2>&1; then
    package_backend=debian
  else
    echo "package_bundle_license no supported package metadata backend" >&2
    exit 1
  fi
fi
case "$package_backend" in
  arch) command -v pacman >/dev/null ;;
  debian) command -v dpkg-query >/dev/null ;;
  *)
    echo "package_bundle_license unsupported package metadata backend: $package_backend" >&2
    exit 1
    ;;
esac

license_root="$stage/share/licenses/noctty/dependencies"
work="$package_inventory.work"
seen_packages="$work/seen-packages.txt"
package_records="$work/package-records.txt"
mkdir -p "$license_root/packages" "$license_root/spdx/exceptions" "$work"
: >"$seen_packages"
: >"$package_records"
: >"$library_inventory"
: >"$package_inventory"
: >"$license_files"

cleanup() {
  if [ -n "${work:-}" ] && [ -d "$work" ]; then
    find "$work" -depth -delete 2>/dev/null || true
  fi
}
trap cleanup EXIT HUP INT TERM

copy_notice() {
  source_file=$1
  relative_target=$2
  target_file="$license_root/$relative_target"
  if [ -f "$target_file" ]; then
    cmp -s "$source_file" "$target_file" || {
      echo "package_bundle_license conflicting notice target: $relative_target" >&2
      exit 1
    }
    return
  fi
  mkdir -p "$(dirname "$target_file")"
  cp -L "$source_file" "$target_file"
  digest=$(sha256sum "$target_file" | awk '{print $1}')
  printf 'share/licenses/noctty/dependencies/%s sha256=%s\n' \
    "$relative_target" "$digest" >>"$license_files"
}

register_package() {
  package=$1
  if grep -Fx "$package" "$seen_packages" >/dev/null; then
    return
  fi

  case "$package_backend" in
    arch)
      package_line=$(pacman -Q "$package" 2>/dev/null) || {
        echo "package_bundle_license package metadata unavailable: $package" >&2
        exit 1
      }
      package_version=${package_line#"$package "}
      license_expression=$(pacman -Qi "$package" | sed -n 's/^Licenses[[:space:]]*:[[:space:]]*//p')
      license_source=arch_package_metadata
      pacman -Ql "$package" | awk '
        $2 ~ /^\/usr\/share\/licenses\// && $2 !~ /\/$/ { print $2 }
      ' | sort -u >"$work/$package-files.txt"
      ;;
    debian)
      package_version=$(dpkg-query -W -f='${Version}\n' "$package" 2>/dev/null) || {
        echo "package_bundle_license package metadata unavailable: $package" >&2
        exit 1
      }
      license_expression=SEE-DEBIAN-COPYRIGHT
      license_source=debian_installed_copyright
      dpkg-query -L "$package" 2>/dev/null | awk '
        /\/copyright$/ { print }
      ' | sort -u >"$work/$package-files.txt"
      ;;
  esac
  test -n "$package_version"
  test -n "$license_expression"
  case "$license_expression" in
    None|LicenseRef-None)
      echo "package_bundle_license empty license expression: $package" >&2
      exit 1
      ;;
  esac

  if [ "$package_backend" = arch ] && [ "$package" = gtksourceview4 ] && [ "$license_expression" = GPL ]; then
    # Arch's legacy field is broader than the installed 4.8 library notice.
    # Pin the exact upstream/binary boundary to the SPDX expression used by
    # the 4.8 source line and retain the canonical text below.
    license_expression=LGPL-2.1-or-later
    license_source=gtksourceview_4_8_upstream_and_binary_notice_override
  fi

  package_files="$work/$package-files.txt"
  package_file_count=0
  while IFS= read -r package_file; do
    [ -n "$package_file" ] || continue
    test -f "$package_file"
    relative_file=${package_file#/}
    copy_notice "$package_file" "packages/$package/$relative_file"
    package_file_count=$((package_file_count + 1))
  done <"$package_files"

  canonical_file_count=0
  unresolved_token_count=0
  for token in $(printf '%s\n' "$license_expression" | tr '()' '  ' | tr ' ' '\n' | sed '/^$/d;/^AND$/d;/^OR$/d;/^WITH$/d'); do
    if [ -f "/usr/share/licenses/spdx/$token.txt" ]; then
      copy_notice "/usr/share/licenses/spdx/$token.txt" "spdx/$token.txt"
      canonical_file_count=$((canonical_file_count + 1))
    elif [ -f "/usr/share/licenses/spdx/exceptions/$token.txt" ]; then
      copy_notice "/usr/share/licenses/spdx/exceptions/$token.txt" \
        "spdx/exceptions/$token.txt"
      canonical_file_count=$((canonical_file_count + 1))
    else
      unresolved_token_count=$((unresolved_token_count + 1))
    fi
  done

  if [ "$package_file_count" -eq 0 ] && [ "$unresolved_token_count" -ne 0 ]; then
    echo "package_bundle_license no text for expression: $package $license_expression" >&2
    exit 1
  fi
  if [ "$package_file_count" -eq 0 ] && [ "$canonical_file_count" -eq 0 ]; then
    echo "package_bundle_license no retained notices: $package" >&2
    exit 1
  fi

  printf '%s version=%s license_expression="%s" package_license_files=%d canonical_spdx_files=%d custom_tokens_covered_by_package_files=%d license_source=%s\n' \
    "$package" "$package_version" "$license_expression" \
    "$package_file_count" "$canonical_file_count" "$unresolved_token_count" \
    "$license_source" >>"$package_inventory"
  printf '%s|%s|%s|%s\n' "$package" "$package_version" \
    "$license_expression" "$license_source" >>"$package_records"
  printf '%s\n' "$package" >>"$seen_packages"
}

while IFS= read -r library; do
  [ -n "$library" ] || continue
  test -f "$library"
  name=$(basename "$library")
  owners="$work/owners.txt"
  case "$package_backend" in
    arch)
      pacman -Qqo "$library" 2>/dev/null | sort -u >"$owners" || true
      ;;
    debian)
      {
        dpkg-query -S "$library" 2>/dev/null || true
        case "$library" in
          /usr/lib/*|/usr/bin/*|/usr/sbin/*)
            dpkg-query -S "${library#/usr}" 2>/dev/null || true
            ;;
        esac
      } | sed 's/: \/.*$//' | sort -u >"$owners"
      ;;
  esac
  owner_count=$(wc -l <"$owners" | tr -d ' ')
  if [ "$owner_count" -ne 1 ]; then
    echo "package_bundle_license library owner unresolved: $library" >&2
    exit 1
  fi
  package=$(sed -n '1p' "$owners")
  register_package "$package"
  source_kind=system

  record=$(grep -F "$package|" "$package_records")
  package_version=$(printf '%s\n' "$record" | cut -d '|' -f 2)
  license_expression=$(printf '%s\n' "$record" | cut -d '|' -f 3)
  license_source=$(printf '%s\n' "$record" | cut -d '|' -f 4)
  printf '%s source=%s path=%s package=%s package_version=%s license="%s" license_source=%s notice_root=share/licenses/noctty/dependencies\n' \
    "$name" "$source_kind" "$library" "$package" "$package_version" \
    "$license_expression" "$license_source" >>"$library_inventory"
done <"$library_sources"

sort -u "$library_inventory" -o "$library_inventory"
sort -u "$package_inventory" -o "$package_inventory"
sort -u "$license_files" -o "$license_files"

source_count=$(wc -l <"$library_sources" | tr -d ' ')
library_count=$(wc -l <"$library_inventory" | tr -d ' ')
library_name_count=$(cut -d ' ' -f 1 "$library_inventory" | sort -u | wc -l | tr -d ' ')
package_count=$(wc -l <"$package_inventory" | tr -d ' ')
license_file_count=$(wc -l <"$license_files" | tr -d ' ')
test "$source_count" -eq "$library_count"
if [ "$library_count" -ne "$library_name_count" ]; then
  echo "package_bundle_license colliding library basenames" >&2
  exit 1
fi
test "$package_count" -gt 0
test "$license_file_count" -gt 0
! grep -E 'license=system-runtime-unresolved|license_source=not_inventoried|LicenseRef-None' \
  "$library_inventory" "$package_inventory" >/dev/null

cleanup
work=
trap - EXIT HUP INT TERM
printf 'package_bundle_licenses backend=%s libraries=%s packages=%s license_files=%s all_copied_host_libraries_accounted=true redistribution_notices_complete=true fail_closed=true\n' \
  "$package_backend" "$library_count" "$package_count" "$license_file_count"
