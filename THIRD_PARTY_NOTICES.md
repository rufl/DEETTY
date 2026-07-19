# Third-Party Notices

NOCTTY and NoctEd remain native Zig/C applications. The items below are either
compiled compatibility sources, generated data inputs, or a repo-local native
fallback; none adds a browser runtime, telemetry service, or runtime download.

## Unicode Character Database 17.0.0

`src/terminal/UnicodeData.zig` is generated from the Unicode Character Database
files pinned by URL and SHA-256 in `dependencies/terminal-unicode.lock.json`.
The complete UAX #29 conformance fixture is retained as
`src/terminal/fixtures/GraphemeBreakTest-17.0.0.txt`. Unicode data and test
files are copyright Unicode, Inc. and distributed under the
[Unicode License Agreement](https://www.unicode.org/license.txt).

## Tree-sitter

Tree-sitter core and the vendored Zig, JSON, C, Bash, and Markdown grammar
sources are used by compatibility tests and optional editor adapters. They are
not linked into the production `noctty` or `nocted` binaries. Version and
license pointers are recorded in `vendor/tree-sitter/LICENSES.md`; the complete
license texts remain beside each vendored source tree.

## GTK Layer Shell

The repo-local same-architecture GTK Layer Shell fallback is
LGPL-3.0-or-later. Its provenance and the distinction between the project
license and MIT-licensed individual source files are documented in
`vendor/gtk-layer-shell/README.md` and `vendor/gtk-layer-shell/LICENSE_MIT.txt`.
Distribution packages normally use the host system library.

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
