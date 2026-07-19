# gtk-layer-shell runtime

This directory contains the minimal runtime/header payload extracted from Arch Linux package `gtk-layer-shell 0.10.1-1` for x86_64.

- Upstream: https://github.com/wmww/gtk-layer-shell
- Package URL: http://mirror.raiolanetworks.com/archlinux/extra/os/x86_64/gtk-layer-shell-0.10.1-1-x86_64.pkg.tar.zst
- License boundary: the extracted `.PKGINFO` declares `LGPL-3.0-or-later`, the Arch package page for `gtk-layer-shell 0.10.1-1` lists `LGPL-3.0-or-later`, and the upstream README says the project is licensed under LGPL-3.0-or-later while most individual source files are MIT. `LICENSE_MIT.txt` is retained as extracted per-file provenance, not as the whole package license.
- Package SHA-256: `1dde94dcb3f6eed8181f08045df26f3fe9bf361fb9f3d7348af3cf192c3c7989`
- Runtime SHA-256: `e9c53613a654333e9610dc342e7264f8d30f26f85f1dfa4e6a22f24507c849eb`
- Included runtime: `usr/lib/libgtk-layer-shell.so.0.10.1`
- Included public header: `usr/include/gtk-layer-shell/gtk-layer-shell.h`
- Included GIR metadata: `usr/share/gir-1.0/GtkLayerShell-0.1.gir`

NOCTTY first tries the system `libgtk-layer-shell.so.0`, then this pinned local runtime. The local payload is an x86_64 development/runtime fallback, not a multi-architecture packaging solution. Dependency-bundle manifests identify this fallback as `LGPL-3.0-or-later`; the generated bundle license payload separately accounts for every copied host library and retains its package notices/canonical SPDX texts. Independent redistribution review and publication remain release operations.
