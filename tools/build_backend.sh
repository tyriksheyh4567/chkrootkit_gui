#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
target=app
mode=release
package=none
jobs=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)
build_dir=
bundle_dir=
output_dir="$project_dir/build/packages"
flutter_bin=${FLUTTER_BIN:-flutter}
appimage_tool=${APPIMAGE_TOOL:-appimagetool}
interactive=false
had_args=$#

usage() {
  cat <<'HELP'
Сборка chkrootkit GUI для Linux.
Без аргументов запускается TUI; для CI используйте параметры.

  --target app|service       GUI с сервисом или только C++-сервис
  --mode debug|release       Режим сборки (release)
  --package none|deb|rpm|appimage|pkg.tar.zst|all
  --jobs N                   Число параллельных задач
  --build-dir PATH           CMake-каталог для target=service
  --bundle-dir PATH          Упаковать готовый bundle без Flutter-сборки
  --output-dir PATH          Каталог пакетов (по умолчанию build/packages)
  --flutter PATH             Исполняемый файл Flutter или FLUTTER_BIN
  --appimage-tool PATH       appimagetool или APPIMAGE_TOOL
  --tui                      Запустить интерактивное меню
  --help                     Эта справка

Примеры:
  ./build.sh
  ./build.sh --target service --mode debug --jobs 4
  ./build.sh --target app --mode release --package deb
  ./build.sh --target app --package all --output-dir dist
HELP
}

fail() { echo "Ошибка: $*" >&2; exit 2; }
value() {
  [[ $# -ge 2 && -n ${2:-} && ${2:-} != --* ]] || fail "Для $1 нужно значение";
}
require_command() { command -v "$1" >/dev/null 2>&1 || fail "Не найдено: $1"; }

while [[ $# -gt 0 ]]; do
  case $1 in
    --target) value "$@"; target=$2; shift 2 ;;
    --mode) value "$@"; mode=$2; shift 2 ;;
    --package) value "$@"; package=$2; shift 2 ;;
    --jobs) value "$@"; jobs=$2; shift 2 ;;
    --build-dir) value "$@"; build_dir=$2; shift 2 ;;
    --bundle-dir) value "$@"; bundle_dir=$2; shift 2 ;;
    --output-dir) value "$@"; output_dir=$2; shift 2 ;;
    --flutter) value "$@"; flutter_bin=$2; shift 2 ;;
    --appimage-tool) value "$@"; appimage_tool=$2; shift 2 ;;
    --tui|--interactive) fail 'Запускайте ./build.sh --tui без дополнительных параметров' ;;
    --help|-h) usage; exit 0 ;;
    *) fail "Неизвестный параметр: $1" ;;
  esac
done
if $interactive || [[ $had_args -eq 0 ]]; then exec make -C "$project_dir" tui; fi

[[ $target == app || $target == service ]] || fail 'target должен быть app или service'
[[ $mode == debug || $mode == release ]] || fail 'mode должен быть debug или release'
[[ $package == none || $package == deb || $package == rpm || $package == appimage || $package == pkg.tar.zst || $package == all ]] || fail 'неподдерживаемый package'
[[ $jobs =~ ^[1-9][0-9]*$ && $jobs -le 256 ]] || fail 'jobs должен быть целым числом от 1 до 256'
[[ $(uname -s) == Linux ]] || fail 'Поддерживается только Linux'
[[ $target == app || $package == none ]] || fail 'пакеты собираются только из target=app'
[[ $package == none || $mode == release ]] || fail 'пакеты собираются только в release'
[[ -z $bundle_dir || ( $target == app && $package != none && -z $build_dir ) ]] || fail '--bundle-dir требует target=app, --package и несовместим с --build-dir'
require_command cmake

[[ $output_dir == /* ]] || output_dir="$project_dir/$output_dir"

check_package_tools() {
  case $package in
    none) ;;
    deb) require_command dpkg-deb ;;
    rpm) require_command rpmbuild ;;
    appimage) require_command "$appimage_tool" ;;
    pkg.tar.zst) require_command bsdtar; require_command zstd ;;
    all)
      require_command dpkg-deb
      require_command rpmbuild
      require_command "$appimage_tool"
      require_command bsdtar
      require_command zstd
      ;;
  esac
}
check_package_tools

architecture=$(uname -m)
case $architecture in
  x86_64|amd64) package_arch=x86_64 ;;
  aarch64|arm64) package_arch=aarch64 ;;
  *) package_arch=$architecture ;;
esac
app_version=$(sed -n "s/^version: *\([^+ ]*\).*/\1/p" "$project_dir/pubspec.yaml" | head -n1)
[[ $app_version =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || fail 'Некорректная версия в pubspec.yaml' 
app_version=${app_version//[^0-9A-Za-z.+:~-]/-}

build_service() {
  build_dir=${build_dir:-$project_dir/build/service/$mode}
  [[ $build_dir == /* ]] || build_dir="$PWD/$build_dir"
  cmake -S "$project_dir/service" -B "$build_dir" "-DCMAKE_BUILD_TYPE=${mode^}"
  cmake --build "$build_dir" --parallel "$jobs"
  service_binary="$build_dir/intermediates_do_not_run/rootkit_guard_service"
  [[ -x $service_binary ]] || fail "Сервис не собран: $service_binary"
  printf 'Сервис собран: %s\n' "$service_binary"
}

find_bundle() {
  local flutter_arch
  case $package_arch in
    x86_64) flutter_arch=x64 ;;
    aarch64) flutter_arch=arm64 ;;
    *) fail 'Неподдерживаемая архитектура Flutter bundle' ;;
  esac
  bundle_dir="$project_dir/build/linux/$flutter_arch/$mode/bundle"
  validate_bundle
}

validate_bundle() {
  [[ -d $bundle_dir ]] || fail "Bundle не найден: $bundle_dir"
  bundle_dir=$(cd -- "$bundle_dir" && pwd)
  [[ -x "$bundle_dir/chkrootkit_gui" && -x "$bundle_dir/rootkit_guard_service" ]] || fail 'Bundle должен содержать GUI и rootkit_guard_service'
}

build_app() {
  [[ -z $build_dir ]] || fail '--build-dir поддерживается только для target=service'
  require_command "$flutter_bin"
  flutter_bin=$(command -v "$flutter_bin")
  cd "$project_dir"
  "$flutter_bin" pub get
  CMAKE_BUILD_PARALLEL_LEVEL="$jobs" "$flutter_bin" build linux "--$mode"
  find_bundle
  printf 'Bundle собран: %s\n' "$bundle_dir"
}

prepare_bundle_root() {
  local root=$1
  rm -rf "$root"
  mkdir -p "$root/opt/chkrootkit_gui" "$root/usr/bin" "$root/usr/share/applications"
  cp -a "$bundle_dir/." "$root/opt/chkrootkit_gui/"
  cat > "$root/usr/bin/chkrootkit_gui" <<'WRAPPER'
#!/bin/sh
exec /opt/chkrootkit_gui/chkrootkit_gui "$@"
WRAPPER
  chmod 755 "$root/usr/bin/chkrootkit_gui"
  cat > "$root/usr/share/applications/com.example.chkrootkit_gui.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=chkrootkit GUI
Comment=Local rootkit scanner GUI
Exec=chkrootkit_gui
Terminal=false
Categories=System;Security;
DESKTOP
}

package_deb() {
  require_command dpkg-deb
  local work="$1/deb"
  local root="$work/root" out="$output_dir/chkrootkit_gui_${app_version}_${package_arch}.deb"
  prepare_bundle_root "$root"
  mkdir -p "$root/DEBIAN"
  cat > "$root/DEBIAN/control" <<CONTROL
Package: chkrootkit-gui
Version: $app_version
Section: admin
Priority: optional
Architecture: $([[ $package_arch == x86_64 ]] && echo amd64 || echo arm64)
Depends: libgtk-3-0, libstdc++6, libc6, libsqlite3-0, polkitd, pkexec
Maintainer: chkrootkit GUI developers
Description: Material 3 GUI for local rootkit scanners
CONTROL
  mkdir -p "$output_dir"
  dpkg-deb --root-owner-group --build "$root" "$out" >/dev/null
  dpkg-deb --info "$out" >/dev/null
  printf 'DEB: %s\n' "$out"
}

package_rpm() {
  require_command rpmbuild
  local work="$1/rpm"
  local top="$work/rpmbuild" source="$work/chkrootkit_gui-$app_version.tar.gz" out
  rm -rf "$work"
  mkdir -p "$top/SOURCES" "$top/SPECS" "$top/BUILD" "$top/RPMS" "$top/SRPMS"
  tar -C "$bundle_dir" -czf "$source" .
  cp "$source" "$top/SOURCES/"
  cat > "$top/SPECS/chkrootkit_gui.spec" <<SPEC
Name: chkrootkit_gui
Version: $app_version
Release: 1
Summary: Material 3 GUI for local rootkit scanners
License: LicenseRef-Unknown
Source0: chkrootkit_gui-$app_version.tar.gz
BuildArch: $package_arch
Requires: gtk3, polkit, sqlite-libs

%description
chkrootkit GUI GUI and its privileged headless service.

%prep
mkdir source
tar -xzf "%{SOURCE0}" -C source

%install
rm -rf "%{buildroot}"
mkdir -p "%{buildroot}/opt/chkrootkit_gui" "%{buildroot}/usr/bin" "%{buildroot}/usr/share/applications"
cp -a source/. "%{buildroot}/opt/chkrootkit_gui/"
printf '#!/bin/sh\\nexec /opt/chkrootkit_gui/chkrootkit_gui "\$@"\\n' > "%{buildroot}/usr/bin/chkrootkit_gui"
chmod 755 "%{buildroot}/usr/bin/chkrootkit_gui"
cat > "%{buildroot}/usr/share/applications/com.example.chkrootkit_gui.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=chkrootkit GUI
Exec=chkrootkit_gui
Terminal=false
Categories=System;Security;
DESKTOP

%files
/opt/chkrootkit_gui
/usr/bin/chkrootkit_gui
/usr/share/applications/com.example.chkrootkit_gui.desktop
SPEC
  rpmbuild --define "_topdir $top" --define "_dbpath $top/db" -bb "$top/SPECS/chkrootkit_gui.spec" >/dev/null
  out=$(find "$top/RPMS" -type f -name '*.rpm' -print -quit)
  [[ -n $out ]] || fail 'rpmbuild не создал RPM'
  mkdir -p "$output_dir"; cp "$out" "$output_dir/"
  printf 'RPM: %s\n' "$output_dir/$(basename "$out")"
}

package_appimage() {
  require_command "$appimage_tool"
  local work="$1/appimage"
  local appdir="$work/AppDir" out="$output_dir/chkrootkit-GUI-$app_version-$package_arch.AppImage"
  rm -rf "$work"; mkdir -p "$appdir/usr/lib/chkrootkit_gui" "$appdir/usr/share/applications"
  cp -a "$bundle_dir/." "$appdir/usr/lib/chkrootkit_gui/"
  cat > "$appdir/AppRun" <<'APPRUN'
#!/bin/sh
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$HERE/usr/lib/chkrootkit_gui/chkrootkit_gui" "$@"
APPRUN
  chmod 755 "$appdir/AppRun"
  cat > "$appdir/usr/share/applications/com.example.chkrootkit_gui.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=chkrootkit GUI
Exec=chkrootkit_gui
Terminal=false
Categories=System;Security;
DESKTOP
  # AppImage requires a desktop entry and matching icon at the AppDir root.
  sed -i '/Name=chkrootkit GUI/a Icon=rootkit-guard' "$appdir/usr/share/applications/com.example.chkrootkit_gui.desktop"
  cp "$appdir/usr/share/applications/com.example.chkrootkit_gui.desktop" "$appdir/"
  cp "$project_dir/packaging/rootkit-guard.svg" "$appdir/rootkit-guard.svg"
  ln -s rootkit-guard.svg "$appdir/.DirIcon"
  mkdir -p "$output_dir"
  ARCH="$package_arch" "$appimage_tool" "$appdir" "$out"
  printf 'AppImage: %s\n' "$out"
}

package_archlinux() {
  require_command bsdtar
  require_command zstd
  local work="$1/arch"
  local root="$work/root" out="$output_dir/chkrootkit_gui-$app_version-1-$package_arch.pkg.tar.zst"
  prepare_bundle_root "$root"
  cat > "$root/.PKGINFO" <<PKGINFO
pkgname = chkrootkit_gui
pkgbase = chkrootkit_gui
pkgver = $app_version-1
pkgdesc = Material 3 GUI for local rootkit scanners
builddate = $(date +%s)
packager = chkrootkit GUI developers
size = $(du -sk "$root" | awk '{print $1 * 1024}')
arch = $package_arch
depend = gtk3
depend = polkit
depend = gcc-libs
depend = sqlite
PKGINFO
  mkdir -p "$output_dir"
  # libalpm matches metadata by its exact name: .PKGINFO, never ./.PKGINFO.
  (cd "$root" && bsdtar --uid 0 --gid 0 -cf - .PKGINFO opt usr) | zstd -q -f -T"$jobs" -o "$out"
  if command -v pacman >/dev/null 2>&1; then
    pacman -Qip "$out" >/dev/null
  fi
  printf 'PKG.TAR.ZST: %s\n' "$out"
}

package_all() {
  mkdir -p "$project_dir/build"
  work=$(mktemp -d "$project_dir/build/package-work.XXXXXX")
  trap 'rm -rf -- "$work"' EXIT
  case $package in
    deb) package_deb "$work" ;;
    rpm) package_rpm "$work" ;;
    appimage) package_appimage "$work" ;;
    pkg.tar.zst) package_archlinux "$work" ;;
    all) package_deb "$work"; package_rpm "$work"; package_appimage "$work"; package_archlinux "$work" ;;
  esac
}

if [[ $target == service ]]; then
  build_service
else
  if [[ -n $bundle_dir ]]; then
    [[ $package != none && -z $build_dir ]] || fail '--bundle-dir требует --package и несовместим с --build-dir'
    validate_bundle
  else
    build_app
  fi
  [[ $package == none ]] || package_all
fi
