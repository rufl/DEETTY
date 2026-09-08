# Third-Party Notices

NOCTTY's first-party code is MIT-licensed. Third-party code, generated data, and
system libraries retain their upstream copyrights and licenses; NOCTTY's MIT
license does not relicense them. None of the dependencies below adds a browser
runtime, telemetry service, or runtime download.

## Unicode Character Database 17.0.0

`src/terminal/UnicodeData.zig` is generated from the Unicode Character Database
files pinned by URL and SHA-256 in `dependencies/terminal-unicode.lock.json`.
The complete UAX #29 conformance fixture is retained as
`src/terminal/fixtures/GraphemeBreakTest-17.0.0.txt`. Unicode data and test
files are copyright Unicode, Inc. and distributed under the Unicode License V3.
The complete [retained license](dependencies/UNICODE-LICENSE.txt) was retrieved
from [Unicode's license page](https://www.unicode.org/license.txt) on 2026-09-06.
Both Linux and Windows install trees retain it as
`share/licenses/noctty/UNICODE-LICENSE.txt`.
Windows portable ZIPs and installers keep this notice beside the executables
as `UNICODE-LICENSE.txt`.

## Tree-sitter

Tree-sitter core and the vendored Zig, JSON, C, Bash, and Markdown generated
parser sources are linked into production NoctEd and reused by compatibility
tests. They are not linked into production `noctty`. Unused upstream workflows,
lockfiles, and container metadata are intentionally omitted; version and license
pointers remain in `vendor/tree-sitter/LICENSES.md`, with complete license texts
beside each vendored source tree.

The embedded Unicode/ICU support in Tree-sitter separately retains its upstream
notice at `vendor/tree-sitter/lib/src/unicode/LICENSE`; it is not covered by
the Tree-sitter MIT notice alone.

Linux install trees include each linked component's complete license at
`share/licenses/noctty/vendor/<component>/LICENSE`, plus the embedded Unicode
notice at `share/licenses/noctty/vendor/tree-sitter/lib/src/unicode/LICENSE`.
The Windows host does not link Tree-sitter.

## System Libraries

Ordinary Linux installs dynamically link host-provided GTK, GtkSourceView,
and their dependencies, and may load GTK Layer Shell. These libraries are
not part of NOCTTY's MIT grant. Installing their development packages is a
build prerequisite, not permission to redistribute a dependency bundle.

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
