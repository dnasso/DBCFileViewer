#
# spec file for package dbc-file-viewer
#
# Copyright (c) 2025 SUSE LLC
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

Name:           dbc-file-viewer
Version:        1.0.1
Release:        0
Summary:        A fast, lightweight viewer for CAN database (.dbc) files
License:        MIT
Group:          Development/Tools/Other
URL:            https://github.com/dnasso/DBCFileViewer
Source0:        %{name}-%{version}.tar.gz
BuildRequires:  cmake >= 3.16
BuildRequires:  gcc-c++
%if 0%{?suse_version}
BuildRequires:  qt6-base-devel
BuildRequires:  qt6-declarative-devel
BuildRequires:  qt6-quickcontrols2-devel
Requires:       libQt6Core6
Requires:       libQt6Gui6
Requires:       libQt6Qml6
Requires:       libQt6Quick6
Requires:       libQt6QuickControls2-6
%endif
%if 0%{?fedora} || 0%{?rhel_version} || 0%{?centos_version}
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel
Requires:       qt6-qtbase
Requires:       qt6-qtdeclarative
%endif

%description
A fast, lightweight viewer for CAN database (.dbc) files. 
Inspect messages, signals, attributes, value tables, and catch 
common issues in a DBC quickly.

Features:
- Open and browse large DBC files
- Instant search/filter for messages, signals, nodes, and value tables
- Detailed message/signal view
- Value table decoding and attribute inspection
- Basic validation (duplicates, overlaps, missing value tables)
- Export selections to CSV/JSON
- Drag-and-drop and recent files

%prep
%setup -q

%build
%cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=%{_prefix}
%cmake_build

%install
%cmake_install

# Install desktop file
mkdir -p %{buildroot}%{_datadir}/applications
cat > %{buildroot}%{_datadir}/applications/%{name}.desktop <<EOF
[Desktop Entry]
Name=DBC File Viewer
Comment=View and analyze CAN database files
Exec=appDBC_Parser
Icon=%{name}
Terminal=false
Type=Application
Categories=Development;Utility;
MimeType=application/x-dbc;
EOF

# Install icon
mkdir -p %{buildroot}%{_datadir}/pixmaps
install -m 0644 deploy-assets/dbctrain.png %{buildroot}%{_datadir}/pixmaps/%{name}.png

%files
%license LICENSE
%doc README.md
%{_bindir}/appDBC_Parser
%{_datadir}/applications/%{name}.desktop
%{_datadir}/pixmaps/%{name}.png

%changelog
