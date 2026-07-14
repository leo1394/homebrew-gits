#!/bin/bash

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
GITS="$ROOT/bin/gits"
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/gits-test.XXXXXX")
TEST_ROOT=$(cd "$TEST_ROOT" && pwd -P)
SHARED_BASE="$TEST_ROOT/central cache"

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_contains() {
    local text="$1"
    local expected="$2"

    [[ "$text" == *"$expected"* ]] || fail "expected '$expected' in '$text'"
}

assert_equals() {
    local actual="$1"
    local expected="$2"

    [ "$actual" = "$expected" ] || fail "expected '$expected', got '$actual'"
}

export HOME="$TEST_ROOT/home"
export GIT_CONFIG_NOSYSTEM=1
export GIT_ALLOW_PROTOCOL=file
mkdir -p "$HOME"

git config --global user.name "gits test"
git config --global user.email "gits@example.invalid"
git config --global init.defaultBranch main
git config --global protocol.file.allow always

assert_equals "$("$GITS" --version)" "gits 0.1.0"
assert_contains "$("$GITS" --help)" "gits init [shared_path]"
formula_sha=$(sed -n 's/^  sha256 "\([0-9a-f]*\)"/\1/p' "$ROOT/Formula/gits.rb")
script_sha=$(shasum -a 256 "$GITS" | awk '{print $1}')
assert_equals "$formula_sha" "$script_sha"
missing_git_output=$(PATH=/nonexistent "$GITS" init 2>&1 || true)
assert_contains "$missing_git_output" "Git is required"

mkdir "$TEST_ROOT/submodule-source"
git -C "$TEST_ROOT/submodule-source" init -q
echo "shared content" > "$TEST_ROOT/submodule-source/content.txt"
git -C "$TEST_ROOT/submodule-source" add content.txt
git -C "$TEST_ROOT/submodule-source" commit -qm "initial submodule"
git clone -q --bare "$TEST_ROOT/submodule-source" "$TEST_ROOT/submodule-origin.git"
git -C "$TEST_ROOT/submodule-source" remote add origin "$TEST_ROOT/submodule-origin.git"

mkdir "$TEST_ROOT/project-source"
git -C "$TEST_ROOT/project-source" init -q
echo "root content" > "$TEST_ROOT/project-source/README.md"
git -C "$TEST_ROOT/project-source" add README.md
git -C "$TEST_ROOT/project-source" commit -qm "initial root"
git -C "$TEST_ROOT/project-source" submodule add -q "$TEST_ROOT/submodule-origin.git" "modules/shared module"
git -C "$TEST_ROOT/project-source" commit -qam "add submodule"
git clone -q --bare "$TEST_ROOT/project-source" "$TEST_ROOT/project-origin.git"
git -C "$TEST_ROOT/project-source" remote add origin "$TEST_ROOT/project-origin.git"

git clone -q "$TEST_ROOT/project-origin.git" "$TEST_ROOT/project-a"
(
    cd "$TEST_ROOT/project-a"
    "$GITS" init "$SHARED_BASE" >/dev/null
)

assert_equals "$(git -C "$TEST_ROOT/project-a" config --local --get gits.sharedSubmodules)" "$SHARED_BASE"
[ -f "$TEST_ROOT/project-a/modules/shared module/content.txt" ] || fail "shared submodule was not initialized"
assert_equals "$(find "$SHARED_BASE/repositories" -type d -name '*.git' | wc -l | tr -d ' ')" "1"

alternate_file=$(git -C "$TEST_ROOT/project-a/modules/shared module" rev-parse --path-format=absolute --git-path objects/info/alternates)
assert_contains "$(cat "$alternate_file")" "$SHARED_BASE/repositories/"
assert_equals "$(git -C "$TEST_ROOT/project-a" status --porcelain)" ""

echo "updated content" >> "$TEST_ROOT/submodule-source/content.txt"
git -C "$TEST_ROOT/submodule-source" commit -qam "update submodule"
git -C "$TEST_ROOT/submodule-source" push -q origin main
git -C "$TEST_ROOT/project-source/modules/shared module" pull -q --ff-only
git -C "$TEST_ROOT/project-source" add "modules/shared module"
git -C "$TEST_ROOT/project-source" commit -qm "update submodule reference"
git -C "$TEST_ROOT/project-source" push -q origin main
(
    cd "$TEST_ROOT/project-a"
    "$GITS" pull >/dev/null
)
assert_contains "$(cat "$TEST_ROOT/project-a/modules/shared module/content.txt")" "updated content"
assert_equals "$(git -C "$TEST_ROOT/project-a" status --porcelain)" ""
assert_contains "$(cd "$TEST_ROOT/project-a" && "$GITS" list)" "(cached)"

echo "dirty root" >> "$TEST_ROOT/project-a/README.md"
echo "dirty submodule" >> "$TEST_ROOT/project-a/modules/shared module/content.txt"
(
    cd "$TEST_ROOT/project-a"
    "$GITS" reset --hard >/dev/null
)
assert_equals "$(git -C "$TEST_ROOT/project-a" status --porcelain)" ""

git clone -q "$TEST_ROOT/project-origin.git" "$TEST_ROOT/project-b"
(
    cd "$TEST_ROOT/project-b"
    "$GITS" init >/dev/null
)

if git -C "$TEST_ROOT/project-b" config --local --get gits.sharedSubmodules >/dev/null 2>&1; then
    fail "shared mode leaked into a project initialized without an explicit path"
fi
[ -f "$TEST_ROOT/project-b/modules/shared module/content.txt" ] || fail "normal submodule was not initialized"

git clone -q "$TEST_ROOT/project-origin.git" "$TEST_ROOT/project-c"
(
    cd "$TEST_ROOT/project-c"
    "$GITS" init "$SHARED_BASE" >/dev/null
)
assert_equals "$(find "$SHARED_BASE/repositories" -type d -name '*.git' | wc -l | tr -d ' ')" "1"

(
    cd "$TEST_ROOT/project-a"
    "$GITS" config --unset >/dev/null
)
if git -C "$TEST_ROOT/project-a" config --local --get gits.sharedSubmodules >/dev/null 2>&1; then
    fail "shared mode was not disabled"
fi

if [ -e "$HOME/.gits-config" ]; then
    fail "legacy global configuration was created"
fi

echo "PASS: gits tests"
