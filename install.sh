#!/bin/bash

set -euo pipefail

REPOSITORY="leo1394/homebrew-gits"
DEFAULT_BRANCH="master"
INSTALL_DIR="${GITS_INSTALL_DIR:-$HOME/.local/bin}"
REQUESTED_VERSION="${1:-${GITS_VERSION:-}}"
TEMP_DIR=""
STAGED_FILE=""

print_info() {
  printf '=> %s\n' "$1"
}

print_error() {
  printf 'gits installer: %s\n' "$1" >&2
}

cleanup() {
  if [ -n "$STAGED_FILE" ]; then
    rm -f "$STAGED_FILE"
  fi
  if [ -n "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
  fi
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

download() {
  curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 10 "$1" -o "$2"
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    print_error "shasum or sha256sum is required"
    exit 1
  fi
}

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    print_error "installing Git requires root access; install Git manually and run this installer again"
    exit 1
  fi
}

install_git() {
  if command -v git >/dev/null 2>&1; then
    return
  fi

  print_info "Git was not found; installing it"
  case "$(uname -s)" in
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        brew install git
      elif command -v xcode-select >/dev/null 2>&1; then
        xcode-select --install || true
        print_error "complete the Command Line Tools installation, then run this installer again"
        exit 1
      else
        print_error "Git is required; install Xcode Command Line Tools and run this installer again"
        exit 1
      fi
      ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        run_as_root apt-get update
        run_as_root apt-get install -y git
      elif command -v dnf >/dev/null 2>&1; then
        run_as_root dnf install -y git
      elif command -v yum >/dev/null 2>&1; then
        run_as_root yum install -y git
      elif command -v pacman >/dev/null 2>&1; then
        run_as_root pacman -Sy --noconfirm git
      elif command -v apk >/dev/null 2>&1; then
        run_as_root apk add git
      else
        print_error "Git is required; no supported package manager was found"
        exit 1
      fi
      ;;
    *)
      print_error "Git is required and could not be installed automatically on this system"
      exit 1
      ;;
  esac

  if ! command -v git >/dev/null 2>&1; then
    print_error "Git installation did not provide a git executable"
    exit 1
  fi
}

if ! command -v curl >/dev/null 2>&1; then
  print_error "curl is required"
  exit 1
fi

install_git

if [ -z "$REQUESTED_VERSION" ]; then
  print_info "Resolving the latest published version"
  REQUESTED_VERSION="$(curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 10 \
    "https://raw.githubusercontent.com/$REPOSITORY/$DEFAULT_BRANCH/VERSION.txt")"
fi

VERSION="${REQUESTED_VERSION#v}"
case "$VERSION" in
  ''|*[!0-9.]*|.*|*..*|*.)
    print_error "invalid version: $REQUESTED_VERSION"
    exit 1
    ;;
esac
if [ "$(printf '%s' "$VERSION" | awk -F. '{print NF}')" -ne 3 ]; then
  print_error "invalid version: $REQUESTED_VERSION"
  exit 1
fi

case "$INSTALL_DIR" in
  /*) ;;
  *)
    print_error "GITS_INSTALL_DIR must be an absolute path"
    exit 1
    ;;
esac

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/gits-install.XXXXXX")"
FORMULA="$TEMP_DIR/gits.rb"
EXECUTABLE="$TEMP_DIR/gits"
TAG="v$VERSION"

print_info "Downloading gits $VERSION"
download "https://raw.githubusercontent.com/$REPOSITORY/$TAG/bin/gits" "$EXECUTABLE"
download "https://raw.githubusercontent.com/$REPOSITORY/$TAG/Formula/gits.rb" "$FORMULA"

EXPECTED_SHA="$(awk '/^[[:space:]]*sha256 "[0-9a-f]+"/ {gsub(/"/, "", $2); print $2; exit}' "$FORMULA")"
if [ "${#EXPECTED_SHA}" -ne 64 ]; then
  print_error "could not read the published SHA256 from Formula/gits.rb"
  exit 1
fi
ACTUAL_SHA="$(sha256_file "$EXECUTABLE")"
if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
  print_error "SHA256 verification failed for gits $VERSION"
  exit 1
fi

chmod 0755 "$EXECUTABLE"
if ! "$EXECUTABLE" --version | grep -Fq "gits version $VERSION "; then
  print_error "downloaded executable did not report gits version $VERSION"
  exit 1
fi

mkdir -p "$INSTALL_DIR"
STAGED_FILE="$(mktemp "$INSTALL_DIR/.gits.XXXXXX")"
cp "$EXECUTABLE" "$STAGED_FILE"
chmod 0755 "$STAGED_FILE"
mv -f "$STAGED_FILE" "$INSTALL_DIR/gits"
STAGED_FILE=""

print_info "Installed gits $VERSION to $INSTALL_DIR/gits"
case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *)
    printf 'Add this directory to PATH, then open a new shell:\n'
    printf '  export PATH="%s:%s"\n' "$INSTALL_DIR" "\$PATH"
    ;;
esac
