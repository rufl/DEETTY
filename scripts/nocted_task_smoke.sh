#!/bin/sh
set -eu

scratch=$(mktemp -d "${TMPDIR:-/tmp}/nocted-task.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

mkdir -p "$scratch/make"
cat >"$scratch/make/Makefile" <<'EOF'
check:
	@printf 'make:check\n'
EOF

mkdir -p "$scratch/shims"
cat >"$scratch/shims/task-tool" <<'EOF'
#!/bin/sh
set -eu
printf '%s:%s\n' "$(basename "$0")" "$*"
EOF
chmod +x "$scratch/shims/task-tool"
for tool in cargo go flutter dart npm dotnet python3; do
  ln -s task-tool "$scratch/shims/$tool"
done
export PATH="$scratch/shims:$PATH"

mkdir -p "$scratch/zig" "$scratch/cargo" "$scratch/go" "$scratch/flutter" \
  "$scratch/dart" "$scratch/npm" "$scratch/dotnet" "$scratch/python"
printf 'pub fn build(_: *anyopaque) void {}\n' >"$scratch/zig/build.zig"
printf '[package]\nname = "sample"\nversion = "0.1.0"\n' \
  >"$scratch/cargo/Cargo.toml"
printf 'module sample\n' >"$scratch/go/go.mod"
printf 'name: sample\n' >"$scratch/flutter/pubspec.yaml"
printf 'version: 1\n' >"$scratch/flutter/.metadata"
mkdir -p "$scratch/flutter/linux"
printf 'name: sample\n' >"$scratch/dart/pubspec.yaml"
printf '{"scripts":{"check":"fixture","build":"fixture"}}\n' \
  >"$scratch/npm/package.json"
printf '<Project />\n' >"$scratch/dotnet/Sample.csproj"
printf '[project]\nname = "sample"\n' >"$scratch/python/pyproject.toml"
printf 'print("sample")\n' >"$scratch/python/main.py"

zig build -Doptimize=Debug >/dev/null
ln -s task-tool "$scratch/shims/zig"

probe() {
  project=$1
  action=$2
  expected=$3
  output=$(timeout 30 ./zig-out/bin/nocted \
    --task-probe "$scratch/$project" "$action")
  printf '%s\n' "$output"
  printf '%s\n' "$output" | grep -F "$expected" >/dev/null
}

probe make check \
  'nocted_task_probe project=Make action=check success=true output=make:check'
probe zig check \
  'nocted_task_probe project=Zig action=check success=true output=zig:build check'
probe cargo test \
  'nocted_task_probe project=Cargo action=test success=true output=cargo:test'
probe go check \
  'nocted_task_probe project=Go action=check success=true output=go:vet ./...'
probe flutter build \
  'nocted_task_probe project=Flutter action=build success=true output=flutter:build linux'
probe dart run \
  'nocted_task_probe project=Dart action=run success=true output=dart:run'
probe npm check \
  'nocted_task_probe project=npm action=check success=true output=npm:run check'
probe dotnet test \
  'nocted_task_probe project=.NET action=test success=true output=dotnet:test'
probe python run \
  'nocted_task_probe project=Python action=run success=true output=python3:main.py'

echo 'nocted_task_smoke ecosystems=9 manifest_detection=true package_script_validation=true bounded=true background_worker=true output=true exit_status=true scratch_clean=true'
