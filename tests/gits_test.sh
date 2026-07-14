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

assert_not_contains() {
    local text="$1"
    local unexpected="$2"

    [[ "$text" != *"$unexpected"* ]] || fail "did not expect '$unexpected' in '$text'"
}

assert_equals() {
    local actual="$1"
    local expected="$2"

    [ "$actual" = "$expected" ] || fail "expected '$expected', got '$actual'"
}

advance_submodule() {
    local message="$1"

    echo "$message" >> "$TEST_ROOT/submodule-source/content.txt"
    git -C "$TEST_ROOT/submodule-source" commit -qam "$message"
    git -C "$TEST_ROOT/submodule-source" push -q origin main
}

assert_submodule_at_recorded_commit() {
    local root="$1"
    local path="$2"
    local expected
    local actual

    expected=$(git -C "$root" rev-parse "HEAD:$path")
    actual=$(git -C "$root/$path" rev-parse HEAD)
    assert_equals "$actual" "$expected"
}

export HOME="$TEST_ROOT/home"
export GIT_CONFIG_NOSYSTEM=1
export GIT_ALLOW_PROTOCOL=file
mkdir -p "$HOME"

git config --global user.name "gits test"
git config --global user.email "gits@example.invalid"
git config --global init.defaultBranch main
git config --global protocol.file.allow always

assert_equals "$("$GITS" --version)" "gits 0.2.2"
assert_contains "$("$GITS" --help)" "gits init [shared_path]"
assert_contains "$("$GITS" --help)" "gits add <args...>"
assert_contains "$("$GITS" --help)" "gits commit <path...|--all>"
formula_sha=$(sed -n 's/^  sha256 "\([0-9a-f]*\)"/\1/p' "$ROOT/Formula/gits.rb")
script_sha=$(shasum -a 256 "$GITS" | awk '{print $1}')
assert_equals "$formula_sha" "$script_sha"
missing_git_output=$(PATH=/nonexistent "$GITS" init 2>&1 || true)
assert_contains "$missing_git_output" "Git is required"
assert_contains "$missing_git_output" $'\033[1;31mgits: Git is required'

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
project_a_list=$(cd "$TEST_ROOT/project-a" && "$GITS" list)
assert_contains "$project_a_list" "(cached)"
assert_contains "$project_a_list" $'\033[1;32mmodules/shared module\033[0m : '
assert_contains "$project_a_list" "$TEST_ROOT/submodule-origin.git"

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
project_b_list=$(cd "$TEST_ROOT/project-b" && "$GITS" list)
assert_contains "$project_b_list" $'shared modules repository: \033[1;31mdisabled\033[0m'
assert_contains "$project_b_list" $'\033[1;32mmodules/shared module\033[0m : '
assert_contains "$project_b_list" "$TEST_ROOT/submodule-origin.git"

echo "remote-only update" >> "$TEST_ROOT/submodule-source/content.txt"
git -C "$TEST_ROOT/submodule-source" commit -qam "remote-only update"
git -C "$TEST_ROOT/submodule-source" push -q origin main
remote_only_commit=$(git -C "$TEST_ROOT/submodule-source" rev-parse HEAD)
(
    cd "$TEST_ROOT/project-b"
    "$GITS" pull >/dev/null
)
assert_equals "$(git -C "$TEST_ROOT/project-b/modules/shared module" rev-parse HEAD)" "$remote_only_commit"
assert_contains "$(git -C "$TEST_ROOT/project-b" status --porcelain)" "modules/shared module"

git clone -q "$TEST_ROOT/project-origin.git" "$TEST_ROOT/project-c"
(
    cd "$TEST_ROOT/project-c"
    "$GITS" init "$SHARED_BASE" >/dev/null
)
assert_equals "$(git -C "$TEST_ROOT/project-c/modules/shared module" rev-parse HEAD)" "$(git -C "$TEST_ROOT/project-c" rev-parse 'HEAD:modules/shared module')"
(
    cd "$TEST_ROOT/project-c"
    "$GITS" pull >/dev/null
)
assert_equals "$(git -C "$TEST_ROOT/project-c/modules/shared module" rev-parse HEAD)" "$remote_only_commit"
assert_contains "$(git -C "$TEST_ROOT/project-c" status --porcelain)" "modules/shared module"
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

DUPLICATE_REMOTES="$TEST_ROOT/duplicate-remotes"
DUPLICATE_SHARED="$TEST_ROOT/duplicate-shared"
mkdir "$DUPLICATE_REMOTES" "$TEST_ROOT/duplicate-build-source"
git -C "$TEST_ROOT/duplicate-build-source" init -q
echo "duplicate content" > "$TEST_ROOT/duplicate-build-source/content.txt"
git -C "$TEST_ROOT/duplicate-build-source" add content.txt
git -C "$TEST_ROOT/duplicate-build-source" commit -qm "initial duplicate submodule"
git clone -q --bare "$TEST_ROOT/duplicate-build-source" "$DUPLICATE_REMOTES/build-scripts"
git -C "$TEST_ROOT/duplicate-build-source" remote add origin "$DUPLICATE_REMOTES/build-scripts"

mkdir "$TEST_ROOT/duplicate-store-source"
git -C "$TEST_ROOT/duplicate-store-source" init -q
echo "store layout" > "$TEST_ROOT/duplicate-store-source/README.md"
git -C "$TEST_ROOT/duplicate-store-source" add README.md
git -C "$TEST_ROOT/duplicate-store-source" commit -qm "initial store layout"
git -C "$TEST_ROOT/duplicate-store-source" submodule add -q "$DUPLICATE_REMOTES/build-scripts" apps/main_app/scripts
git -C "$TEST_ROOT/duplicate-store-source" submodule add -q "$DUPLICATE_REMOTES/build-scripts" apps/companion_app/scripts
git config --file "$TEST_ROOT/duplicate-store-source/.gitmodules" submodule.apps/main_app/scripts.url ../build-scripts
git config --file "$TEST_ROOT/duplicate-store-source/.gitmodules" submodule.apps/companion_app/scripts.url ../build-scripts
git -C "$TEST_ROOT/duplicate-store-source" add .gitmodules apps
git -C "$TEST_ROOT/duplicate-store-source" commit -qm "add duplicate submodule paths"
git clone -q --bare "$TEST_ROOT/duplicate-store-source" "$DUPLICATE_REMOTES/store-layout"
git -C "$TEST_ROOT/duplicate-store-source" remote add origin "$DUPLICATE_REMOTES/store-layout"

assert_equals "$(git config --file "$TEST_ROOT/duplicate-store-source/.gitmodules" --get submodule.apps/main_app/scripts.url)" "../build-scripts"
assert_equals "$(git config --file "$TEST_ROOT/duplicate-store-source/.gitmodules" --get submodule.apps/companion_app/scripts.url)" "../build-scripts"

git clone -q "$DUPLICATE_REMOTES/store-layout" "$TEST_ROOT/duplicate-normal"
(
    cd "$TEST_ROOT/duplicate-normal"
    "$GITS" init >/dev/null
)
[ -f "$TEST_ROOT/duplicate-normal/apps/main_app/scripts/content.txt" ] || fail "main app duplicate submodule was not initialized"
[ -f "$TEST_ROOT/duplicate-normal/apps/companion_app/scripts/content.txt" ] || fail "companion app duplicate submodule was not initialized"

echo "normal pull update" >> "$TEST_ROOT/duplicate-build-source/content.txt"
git -C "$TEST_ROOT/duplicate-build-source" commit -qam "normal pull update"
git -C "$TEST_ROOT/duplicate-build-source" push -q origin main
git -C "$TEST_ROOT/duplicate-store-source/apps/main_app/scripts" pull -q --ff-only
git -C "$TEST_ROOT/duplicate-store-source/apps/companion_app/scripts" pull -q --ff-only
git -C "$TEST_ROOT/duplicate-store-source" add apps/main_app/scripts apps/companion_app/scripts
git -C "$TEST_ROOT/duplicate-store-source" commit -qm "update both duplicate submodules"
git -C "$TEST_ROOT/duplicate-store-source" push -q origin main
(
    cd "$TEST_ROOT/duplicate-normal"
    "$GITS" pull >/dev/null
)
assert_submodule_at_recorded_commit "$TEST_ROOT/duplicate-normal" apps/main_app/scripts
assert_submodule_at_recorded_commit "$TEST_ROOT/duplicate-normal" apps/companion_app/scripts
assert_equals "$(git -C "$TEST_ROOT/duplicate-normal" status --porcelain)" ""

echo "dirty main" >> "$TEST_ROOT/duplicate-normal/apps/main_app/scripts/content.txt"
echo "dirty companion" >> "$TEST_ROOT/duplicate-normal/apps/companion_app/scripts/content.txt"
(
    cd "$TEST_ROOT/duplicate-normal"
    "$GITS" reset --hard >/dev/null
)
assert_equals "$(git -C "$TEST_ROOT/duplicate-normal/apps/main_app/scripts" status --porcelain)" ""
assert_equals "$(git -C "$TEST_ROOT/duplicate-normal/apps/companion_app/scripts" status --porcelain)" ""
assert_submodule_at_recorded_commit "$TEST_ROOT/duplicate-normal" apps/main_app/scripts
assert_submodule_at_recorded_commit "$TEST_ROOT/duplicate-normal" apps/companion_app/scripts

git clone -q "$DUPLICATE_REMOTES/store-layout" "$TEST_ROOT/duplicate-shared-project"
duplicate_init_output=$(
    cd "$TEST_ROOT/duplicate-shared-project"
    "$GITS" init "$DUPLICATE_SHARED"
)
duplicate_init_fetches=$(printf '%s\n' "$duplicate_init_output" | grep -Ec 'git clone --mirror|remote update --prune')
assert_equals "$duplicate_init_fetches" "1"
assert_equals "$(find "$DUPLICATE_SHARED/repositories" -type d -name '*.git' | wc -l | tr -d ' ')" "1"

main_url=$(git -C "$TEST_ROOT/duplicate-shared-project" config --local --get submodule.apps/main_app/scripts.url)
companion_url=$(git -C "$TEST_ROOT/duplicate-shared-project" config --local --get submodule.apps/companion_app/scripts.url)
assert_equals "$main_url" "$companion_url"

echo "shared pull update" >> "$TEST_ROOT/duplicate-build-source/content.txt"
git -C "$TEST_ROOT/duplicate-build-source" commit -qam "shared pull update"
git -C "$TEST_ROOT/duplicate-build-source" push -q origin main
git -C "$TEST_ROOT/duplicate-store-source/apps/main_app/scripts" pull -q --ff-only
git -C "$TEST_ROOT/duplicate-store-source/apps/companion_app/scripts" pull -q --ff-only
git -C "$TEST_ROOT/duplicate-store-source" add apps/main_app/scripts apps/companion_app/scripts
git -C "$TEST_ROOT/duplicate-store-source" commit -qm "update shared duplicate submodules"
git -C "$TEST_ROOT/duplicate-store-source" push -q origin main
duplicate_pull_output=$(
    cd "$TEST_ROOT/duplicate-shared-project"
    "$GITS" pull 2>&1
)
duplicate_pull_fetches=$(printf '%s\n' "$duplicate_pull_output" | grep -c 'remote update --prune')
assert_equals "$duplicate_pull_fetches" "1"
assert_not_contains "$duplicate_pull_output" "Fetching submodule"
assert_submodule_at_recorded_commit "$TEST_ROOT/duplicate-shared-project" apps/main_app/scripts
assert_submodule_at_recorded_commit "$TEST_ROOT/duplicate-shared-project" apps/companion_app/scripts
assert_equals "$(git -C "$TEST_ROOT/duplicate-shared-project" status --porcelain)" ""

main_alternate=$(git -C "$TEST_ROOT/duplicate-shared-project/apps/main_app/scripts" rev-parse --path-format=absolute --git-path objects/info/alternates)
companion_alternate=$(git -C "$TEST_ROOT/duplicate-shared-project/apps/companion_app/scripts" rev-parse --path-format=absolute --git-path objects/info/alternates)
assert_equals "$(cat "$main_alternate")" "$(cat "$companion_alternate")"

EDITOR_ACCEPT="$TEST_ROOT/editor-accept"
EDITOR_SUPPLEMENT="$TEST_ROOT/editor-supplement"
EDITOR_INTERRUPT="$TEST_ROOT/editor-interrupt"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$EDITOR_ACCEPT"
printf '%s\n' '#!/bin/sh' 'first=$(sed -n "1p" "$1")' 'printf "%s custom detail\n" "$first" > "$1"' > "$EDITOR_SUPPLEMENT"
printf '%s\n' '#!/bin/sh' 'kill -INT "$PPID"' 'exit 130' > "$EDITOR_INTERRUPT"
chmod +x "$EDITOR_ACCEPT" "$EDITOR_SUPPLEMENT" "$EDITOR_INTERRUPT"

mkdir "$TEST_ROOT/add-project"
git -C "$TEST_ROOT/add-project" init -q
echo "root content" > "$TEST_ROOT/add-project/root.txt"
mkdir "$TEST_ROOT/add-project/non-submodule-directory"
echo "directory content" > "$TEST_ROOT/add-project/non-submodule-directory/content.txt"
git -C "$TEST_ROOT/add-project" add .
git -C "$TEST_ROOT/add-project" commit -qm "initial add project"
(
    cd "$TEST_ROOT/add-project"
    "$GITS" add -q "$TEST_ROOT/submodule-origin.git" scripts
)
git -C "$TEST_ROOT/add-project" submodule add -q "$TEST_ROOT/submodule-origin.git" android
git -C "$TEST_ROOT/add-project" submodule add -q "$TEST_ROOT/submodule-origin.git" ios
git -C "$TEST_ROOT/add-project" commit -qam "add test submodules"

advance_submodule "update scripts"
git -C "$TEST_ROOT/add-project/scripts" pull -q --ff-only
(
    cd "$TEST_ROOT/add-project"
    GIT_EDITOR="$EDITOR_ACCEPT" "$GITS" commit scripts/ >/dev/null
)
assert_equals "$(git -C "$TEST_ROOT/add-project" log -1 --pretty=%s)" "update submodule: scripts"

advance_submodule "update scripts and android"
git -C "$TEST_ROOT/add-project/scripts" pull -q --ff-only
git -C "$TEST_ROOT/add-project/android" pull -q --ff-only
(
    cd "$TEST_ROOT/add-project"
    GIT_EDITOR="$EDITOR_ACCEPT" "$GITS" commit scripts android >/dev/null
)
assert_equals "$(git -C "$TEST_ROOT/add-project" log -1 --pretty=%s)" "update submodule: scripts android"

advance_submodule "update all submodules"
git -C "$TEST_ROOT/add-project/scripts" pull -q --ff-only
git -C "$TEST_ROOT/add-project/android" pull -q --ff-only
git -C "$TEST_ROOT/add-project/ios" pull -q --ff-only
(
    cd "$TEST_ROOT/add-project"
    GIT_EDITOR="$EDITOR_ACCEPT" "$GITS" commit --all >/dev/null
)
assert_equals "$(git -C "$TEST_ROOT/add-project" log -1 --pretty=%s)" "update submodule: scripts android ios"

echo "directory update" >> "$TEST_ROOT/add-project/non-submodule-directory/content.txt"
(
    cd "$TEST_ROOT/add-project"
    GIT_EDITOR="$EDITOR_ACCEPT" "$GITS" commit non-submodule-directory >/dev/null
)
assert_equals "$(git -C "$TEST_ROOT/add-project" log -1 --pretty=%s)" "feat:"

advance_submodule "mixed update"
git -C "$TEST_ROOT/add-project/ios" pull -q --ff-only
echo "root update" >> "$TEST_ROOT/add-project/root.txt"
(
    cd "$TEST_ROOT/add-project"
    GIT_EDITOR="$EDITOR_ACCEPT" "$GITS" commit . >/dev/null
)
assert_equals "$(git -C "$TEST_ROOT/add-project" log -1 --pretty=%s)" "feat:"

echo "custom update" >> "$TEST_ROOT/add-project/root.txt"
(
    cd "$TEST_ROOT/add-project"
    GIT_EDITOR="$EDITOR_SUPPLEMENT" "$GITS" commit root.txt >/dev/null
)
assert_equals "$(git -C "$TEST_ROOT/add-project" log -1 --pretty=%s)" "feat: custom detail"

echo "previously staged" >> "$TEST_ROOT/add-project/root.txt"
git -C "$TEST_ROOT/add-project" add root.txt
echo "must be rolled back" > "$TEST_ROOT/add-project/rollback.txt"
before_interrupt=$(git -C "$TEST_ROOT/add-project" diff --cached)
if (
    cd "$TEST_ROOT/add-project"
    GIT_EDITOR="$EDITOR_INTERRUPT" "$GITS" commit rollback.txt >/dev/null 2>&1
); then
    fail "interrupted add unexpectedly succeeded"
fi
after_interrupt=$(git -C "$TEST_ROOT/add-project" diff --cached)
assert_equals "$after_interrupt" "$before_interrupt"
assert_equals "$(git -C "$TEST_ROOT/add-project" diff --cached --name-only)" "root.txt"

echo "PASS: gits tests"
