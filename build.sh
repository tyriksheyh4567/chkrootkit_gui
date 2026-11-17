#!/usr/bin/env bash
set -euo pipefail
project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ $# -eq 0 ]]; then
  exec make -C "$project_dir" tui
fi
if [[ ${1:-} == --tui || ${1:-} == --interactive || ${1:-} == tui ]]; then
  if [[ $# -ne 1 ]]; then
    echo 'TUI запускается без дополнительных аргументов; задайте параметры в форме.' >&2
    exit 2
  fi
  exec make -C "$project_dir" tui
fi
exec bash "$project_dir/tools/build_backend.sh" "$@"
