#!/usr/bin/env bash
# Installs the Godot editor (headless-capable) into ~/godot/godot and,
# optionally, the export templates.
#
# Usage:
#   bash tools/install_godot.sh                     # editor only
#   bash tools/install_godot.sh --templates desktop # + Windows/Linux/macOS templates
#   bash tools/install_godot.sh --templates all     # + every platform (~1 GB)
set -euo pipefail

VERSION="${GODOT_VERSION:-4.7.2}"
TEMPLATES="none"
if [[ "${1:-}" == "--templates" ]]; then
  TEMPLATES="${2:-desktop}"
fi

BASE="https://downloads.godotengine.org/?version=${VERSION}&flavor=stable"
GODOT_DIR="${HOME}/godot"
TEMPLATE_DIR="${HOME}/.local/share/godot/export_templates/${VERSION}.stable"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

if [[ ! -x "${GODOT_DIR}/godot" ]]; then
  echo "Downloading Godot ${VERSION}..."
  mkdir -p "${GODOT_DIR}"
  curl -fsSL -o "${TMP}/godot.zip" "${BASE}&slug=linux.x86_64.zip&platform=linux.64"
  unzip -q "${TMP}/godot.zip" -d "${TMP}/godot"
  mv "${TMP}/godot/Godot_v${VERSION}-stable_linux.x86_64" "${GODOT_DIR}/godot"
  chmod +x "${GODOT_DIR}/godot"
fi

if [[ "${TEMPLATES}" != "none" ]]; then
  echo "Downloading export templates (${TEMPLATES})..."
  mkdir -p "${TEMPLATE_DIR}"
  curl -fsSL -o "${TMP}/templates.tpz" "${BASE}&slug=export_templates.tpz&platform=templates"
  unzip -q "${TMP}/templates.tpz" -d "${TMP}/templates"
  if [[ "${TEMPLATES}" == "all" ]]; then
    cp -r "${TMP}/templates/templates/." "${TEMPLATE_DIR}/"
  else
    for file in version.txt linux_release.x86_64 linux_debug.x86_64 \
      windows_release_x86_64.exe windows_debug_x86_64.exe macos.zip; do
      cp "${TMP}/templates/templates/${file}" "${TEMPLATE_DIR}/"
    done
  fi
fi

"${GODOT_DIR}/godot" --version
echo "Godot installed in ${GODOT_DIR} (add it to PATH)."
