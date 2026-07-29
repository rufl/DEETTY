# Third-Party Notices

NOCTTY and NoctEd remain native Zig/C applications. The items below are either
compiled sources, generated data inputs, or a repo-local native packaging
payload; none adds a browser runtime, telemetry service, or runtime download.

## Unicode Character Database 17.0.0

`src/terminal/UnicodeData.zig` is generated from the Unicode Character Database
files pinned by URL and SHA-256 in `dependencies/terminal-unicode.lock.json`.
The complete UAX #29 conformance fixture is retained as
`src/terminal/fixtures/GraphemeBreakTest-17.0.0.txt`. Unicode data and test
files are copyright Unicode, Inc. and distributed under the
[Unicode License Agreement](https://www.unicode.org/license.txt).

## Tree-sitter

Tree-sitter core and the vendored Zig, JSON, C, Bash, and Markdown generated
parser sources are linked into production NoctEd and reused by compatibility
tests. They are not linked into production `noctty`. Unused upstream workflows,
lockfiles, and container metadata are intentionally omitted; version and license
pointers remain in `vendor/tree-sitter/LICENSES.md`, with complete license texts
beside each vendored source tree.

## GTK Layer Shell

The repo-local same-architecture GTK Layer Shell packaging payload is
LGPL-3.0-or-later. Its provenance and the distinction between the project
license and MIT-licensed individual source files are documented in
`vendor/gtk-layer-shell/README.md` and `vendor/gtk-layer-shell/LICENSE_MIT.txt`.
Runtime loading uses the system soname; distribution packages provide it and
bundles expose their private copy through the launcher library path.

## Generated Dependency-Bundle Notices

Same-architecture dependency bundles retain Arch/pacman or Debian/dpkg package
ownership, installed package notices/copyright files, and available canonical
SPDX license/exception texts for every copied shared library under
`share/licenses/noctty/dependencies`. The adjacent bundle
manifest records each library's source path, package, version, license
expression/source, and each retained notice digest. This payload is generated
from the exact build host by `scripts/package_bundle_licenses.sh`; it is not
part of the ordinary dynamically linked install tree and is not a legal review
or publication receipt.
