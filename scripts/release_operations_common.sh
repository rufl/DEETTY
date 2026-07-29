retain_tmp=

release_operations_cleanup() {
  if [ -n "$retain_tmp" ]; then rm -f -- "$retain_tmp"; fi
}
trap release_operations_cleanup EXIT HUP INT TERM

retain_from_stdin() {
  target_file=$1
  target_dir=$(dirname "$target_file")
  mkdir -p "$target_dir"
  retain_tmp=$(mktemp "$target_dir/.noctty-retain.XXXXXX")
  cat >"$retain_tmp"
  chmod 0644 "$retain_tmp"
  mv -f "$retain_tmp" "$target_file"
  retain_tmp=
}

retain_file() {
  source_file=$1
  target_file=$2
  retain_from_stdin "$target_file" <"$source_file"
}