Name:           deetty
Version:        0.1.0
Release:        1%{?dist}
Summary:        Zig-native terminal workspace for Plasma and Noctalia
License:        MIT AND Unicode-3.0 AND Unicode-DFS-2016 AND ICU
URL:            https://github.com/rufl/DEETTY
Source0:        %{name}-%{version}.tar.gz
BuildRequires:  zig >= 0.17
BuildRequires:  pkgconfig(gtk+-3.0)
BuildRequires:  pkgconfig(epoxy)
BuildRequires:  pkgconfig(gtksourceview-4)
Requires:       gtk3
Requires:       libepoxy
Requires:       gtk-layer-shell
Requires:       gtksourceview4

%description
Native PTY/VT terminal workspace with dropdown, windowed, fullscreen,
tabs, splits, project workspaces, and the standalone NoctEd editor.

%prep
%setup -q

%build
zig build -Doptimize=ReleaseSafe --prefix %{_prefix}

%install
rm -rf %{buildroot}
zig build -Doptimize=ReleaseSafe --prefix %{buildroot}%{_prefix}

%files
%{_bindir}/deetty
%{_bindir}/nocted
%{_datadir}/applications/com.deetty.DEETTY.desktop
%{_datadir}/applications/com.deetty.NoctEd.desktop
%{_datadir}/kio/servicemenus/deettyhere.desktop
%{_datadir}/metainfo/com.deetty.DEETTY.metainfo.xml
%{_datadir}/metainfo/com.deetty.NoctEd.metainfo.xml
%{_datadir}/icons/hicolor/*/apps/com.deetty.DEETTY.*
%{_datadir}/icons/hicolor/*/apps/com.deetty.NoctEd.*
%{_datadir}/nocted/*
%{_datadir}/deetty/noctalia/*
%license %{_datadir}/licenses/deetty/

%changelog
* Tue Jul 14 2026 LichForge <opensource@lichforge.com> - 0.1.0-1
- Initial native Linux release
