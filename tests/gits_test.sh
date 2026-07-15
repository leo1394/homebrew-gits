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

assert_equals "$("$GITS" --version)" "gits 0.2.6"
assert_contains "$("$GITS" --help)" "gits init [shared_path]"
assert_contains "$("$GITS" --help)" "gits add <args...>"
assert_contains "$("$GITS" --help)" "gits admit <path...|--all>"
assert_contains "$("$GITS" --help)" "deprecated alias for gits admit"
assert_contains "$("$GITS" --help)" "gits clean [--scan <root>...]"
assert_contains "$("$GITS" --help)" "gits clean --apply"
assert_contains "$("$GITS" --help)" "gits completion <shell>"
assert_contains "$(cat "$ROOT/Formula/gits.rb")" 'chmod 0755, bin/"gits"'

outside_git="$TEST_ROOT/outside git"
bash_completion_file="$TEST_ROOT/gits.bash"
zsh_completion_file="$TEST_ROOT/_gits"
fish_completion_file="$TEST_ROOT/gits.fish"
mkdir "$outside_git"
(
    cd "$outside_git"
    "$GITS" completion bash > "$bash_completion_file"
    "$GITS" completion zsh > "$zsh_completion_file"
    "$GITS" completion fish > "$fish_completion_file"
)
[ -s "$bash_completion_file" ] || fail "bash completion output is empty"
[ -s "$zsh_completion_file" ] || fail "zsh completion output is empty"
[ -s "$fish_completion_file" ] || fail "fish completion output is empty"
bash -n "$bash_completion_file"
if command -v zsh >/dev/null 2>&1; then
    zsh -n "$zsh_completion_file"
fi
if command -v fish >/dev/null 2>&1; then
    fish -n "$fish_completion_file"
fi
assert_contains "$(cat "$bash_completion_file")" "complete -F _gits gits"
assert_contains "$(cat "$zsh_completion_file")" "compdef _gits gits"
assert_contains "$(cat "$zsh_completion_file")" "'admit:stage changes"
assert_contains "$(cat "$fish_completion_file")" "complete -c gits"
assert_contains "$(cat "$fish_completion_file")" "-a admit"

bash_adm_completion=$(/bin/bash -c '
    source "$1"
    COMP_WORDS=(gits adm)
    COMP_CWORD=1
    _gits
    printf "%s" "${COMPREPLY[*]}"
' _ "$bash_completion_file")
assert_equals "$bash_adm_completion" "admit"

bash_ad_completion=$(/bin/bash -c '
    source "$1"
    COMP_WORDS=(gits ad)
    COMP_CWORD=1
    _gits
    printf "%s" "${COMPREPLY[*]}"
' _ "$bash_completion_file")
assert_equals "$bash_ad_completion" "add admit"

bash_clean_completion=$(/bin/bash -c '
    source "$1"
    COMP_WORDS=(gits clean --)
    COMP_CWORD=2
    _gits
    printf "%s" "${COMPREPLY[*]}"
' _ "$bash_completion_file")
assert_equals "$bash_clean_completion" "--scan --apply --forget-scan"

bash_reset_completion=$(/bin/bash -c '
    source "$1"
    COMP_WORDS=(gits reset --)
    COMP_CWORD=2
    _gits
    printf "%s" "${COMPREPLY[*]}"
' _ "$bash_completion_file")
assert_equals "$bash_reset_completion" "--hard"

bash_shell_completion=$(/bin/bash -c '
    source "$1"
    COMP_WORDS=(gits completion z)
    COMP_CWORD=2
    _gits
    printf "%s" "${COMPREPLY[*]}"
' _ "$bash_completion_file")
assert_equals "$bash_shell_completion" "zsh"

if "$GITS" completion powershell > "$TEST_ROOT/invalid-completion.out" 2>&1; then
    fail "unknown completion shell should fail"
fi
invalid_completion_output=$(cat "$TEST_ROOT/invalid-completion.out")
assert_contains "$invalid_completion_output" "unsupported completion shell 'powershell'"
assert_contains "$invalid_completion_output" $'\033[1;31mgits: unsupported completion shell'

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
assert_equals "$(git -C "$TEST_ROOT/project-a/modules/shared module" symbolic-ref --short -q HEAD)" "main"
assert_equals "$(git -C "$TEST_ROOT/project-a/modules/shared module" rev-parse --abbrev-ref '@{upstream}')" "origin/main"

alternate_file=$(git -C "$TEST_ROOT/project-a/modules/shared module" rev-parse --path-format=absolute --git-path objects/info/alternates)
current_objects=$(grep -F "$SHARED_BASE/repositories/" "$alternate_file")
mirror_name=$(basename "$(dirname "$current_objects")")
stale_objects="$TEST_ROOT/stale shared/repositories/$mirror_name/objects"
user_objects="$TEST_ROOT/submodule-origin.git/objects"
printf '%s\n%s\n%s\n' "$stale_objects" "$current_objects" "$user_objects" > "$alternate_file"
(
    cd "$TEST_ROOT/project-a"
    "$GITS" init "$SHARED_BASE" >/dev/null
)
alternate_contents=$(cat "$alternate_file")
assert_not_contains "$alternate_contents" "$stale_objects"
assert_contains "$alternate_contents" "$current_objects"
assert_contains "$alternate_contents" "$user_objects"
submodule_status=$(git -C "$TEST_ROOT/project-a/modules/shared module" status --porcelain 2>&1)
assert_not_contains "$submodule_status" "unable to normalize alternate object path"
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
assert_equals "$(git -C "$TEST_ROOT/project-a/modules/shared module" symbolic-ref --short -q HEAD)" "main"

git clone -q "$TEST_ROOT/project-origin.git" "$TEST_ROOT/project-b"
(
    cd "$TEST_ROOT/project-b"
    "$GITS" init >/dev/null
)

if git -C "$TEST_ROOT/project-b" config --local --get gits.sharedSubmodules >/dev/null 2>&1; then
    fail "shared mode leaked into a project initialized without an explicit path"
fi
[ -f "$TEST_ROOT/project-b/modules/shared module/content.txt" ] || fail "normal submodule was not initialized"
assert_equals "$(git -C "$TEST_ROOT/project-b/modules/shared module" symbolic-ref --short -q HEAD)" "main"
assert_equals "$(git -C "$TEST_ROOT/project-b/modules/shared module" rev-parse --abbrev-ref '@{upstream}')" "origin/main"
project_b_list=$(cd "$TEST_ROOT/project-b" && "$GITS" list)
assert_contains "$project_b_list" $'shared modules repository: \033[1;31mdisabled\033[0m'
assert_contains "$project_b_list" $'\033[1;32mmodules/shared module\033[0m : '
assert_contains "$project_b_list" "$TEST_ROOT/submodule-origin.git"
disabled_clean_output=$(cd "$TEST_ROOT/project-b" && "$GITS" clean 2>&1 || true)
assert_contains "$disabled_clean_output" "clean requires shared mode"

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

printf '%s\n%s\n%s\n' "$stale_objects" "$current_objects" "$user_objects" > "$alternate_file"
(
    cd "$TEST_ROOT/project-a"
    "$GITS" config --unset >/dev/null
)
if git -C "$TEST_ROOT/project-a" config --local --get gits.sharedSubmodules >/dev/null 2>&1; then
    fail "shared mode was not disabled"
fi
alternate_contents=$(cat "$alternate_file")
assert_not_contains "$alternate_contents" "$stale_objects"
assert_not_contains "$alternate_contents" "$current_objects"
assert_contains "$alternate_contents" "$user_objects"
[ -d "$(dirname "$current_objects")" ] || fail "shared mirror was deleted by config --unset"
submodule_status=$(git -C "$TEST_ROOT/project-a/modules/shared module" status --porcelain 2>&1)
assert_not_contains "$submodule_status" "unable to normalize alternate object path"
git -C "$TEST_ROOT/project-a/modules/shared module" pull --ff-only >/dev/null

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
ln -s build-scripts "$DUPLICATE_REMOTES/build-scripts.git"
git -C "$TEST_ROOT/duplicate-build-source" remote add origin "$DUPLICATE_REMOTES/build-scripts"

mkdir "$TEST_ROOT/duplicate-store-source"
git -C "$TEST_ROOT/duplicate-store-source" init -q
echo "store layout" > "$TEST_ROOT/duplicate-store-source/README.md"
git -C "$TEST_ROOT/duplicate-store-source" add README.md
git -C "$TEST_ROOT/duplicate-store-source" commit -qm "initial store layout"
git -C "$TEST_ROOT/duplicate-store-source" submodule add -q "$DUPLICATE_REMOTES/build-scripts" apps/main_app/scripts
git -C "$TEST_ROOT/duplicate-store-source" submodule add -q "$DUPLICATE_REMOTES/build-scripts.git" apps/companion_app/scripts
git config --file "$TEST_ROOT/duplicate-store-source/.gitmodules" submodule.apps/main_app/scripts.url ../build-scripts
git config --file "$TEST_ROOT/duplicate-store-source/.gitmodules" submodule.apps/companion_app/scripts.url ../build-scripts.git
git -C "$TEST_ROOT/duplicate-store-source" add .gitmodules apps
git -C "$TEST_ROOT/duplicate-store-source" commit -qm "add duplicate submodule paths"
git clone -q --bare "$TEST_ROOT/duplicate-store-source" "$DUPLICATE_REMOTES/store-layout"
git -C "$TEST_ROOT/duplicate-store-source" remote add origin "$DUPLICATE_REMOTES/store-layout"

assert_equals "$(git config --file "$TEST_ROOT/duplicate-store-source/.gitmodules" --get submodule.apps/main_app/scripts.url)" "../build-scripts"
assert_equals "$(git config --file "$TEST_ROOT/duplicate-store-source/.gitmodules" --get submodule.apps/companion_app/scripts.url)" "../build-scripts.git"

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
assert_not_contains "$main_url" ".git"
assert_contains "$companion_url" ".git"

main_alternate=$(git -C "$TEST_ROOT/duplicate-shared-project/apps/main_app/scripts" rev-parse --path-format=absolute --git-path objects/info/alternates)
companion_alternate=$(git -C "$TEST_ROOT/duplicate-shared-project/apps/companion_app/scripts" rev-parse --path-format=absolute --git-path objects/info/alternates)
canonical_objects=$(cat "$main_alternate")
legacy_hash=$(printf '%s' "$companion_url" | git hash-object --stdin)
legacy_objects="$DUPLICATE_SHARED/repositories/build-scripts-${legacy_hash:0:12}.git/objects"
printf '%s\n%s\n' "$canonical_objects" "$legacy_objects" > "$companion_alternate"
(
    cd "$TEST_ROOT/duplicate-shared-project"
    "$GITS" init "$DUPLICATE_SHARED" >/dev/null
)
assert_equals "$(cat "$companion_alternate")" "$canonical_objects"

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

assert_equals "$(cat "$main_alternate")" "$(cat "$companion_alternate")"

CLEAN_PROJECT="$TEST_ROOT/clean-control"
CLEAN_SHARED="$TEST_ROOT/clean shared"
CLEAN_SCAN_ONE="$TEST_ROOT/clean scan one"
CLEAN_SCAN_TWO="$TEST_ROOT/clean scan two"
CLEAN_USED_MIRROR="$CLEAN_SHARED/repositories/used.git"
CLEAN_ORPHAN_MIRROR="$CLEAN_SHARED/repositories/orphan.git"
CLEAN_REVIVED_MIRROR="$CLEAN_SHARED/repositories/revived.git"
CLEAN_STATE="$CLEAN_SHARED/.gits/clean-config"
mkdir -p "$CLEAN_PROJECT" "$CLEAN_SHARED/repositories" "$CLEAN_SCAN_ONE/absolute/repo/objects/info" "$CLEAN_SCAN_TWO/relative/repo/objects/info"
git -C "$CLEAN_PROJECT" init -q
git -C "$CLEAN_PROJECT" config --local gits.sharedSubmodules "$CLEAN_SHARED"
git init --bare -q "$CLEAN_USED_MIRROR"
git init --bare -q "$CLEAN_ORPHAN_MIRROR"
git init --bare -q "$CLEAN_REVIVED_MIRROR"
used_unreachable_object=$(printf 'unreachable but still borrowed' | git -C "$CLEAN_USED_MIRROR" hash-object -w --stdin)
printf '%s\n' "$CLEAN_USED_MIRROR/objects" > "$CLEAN_SCAN_ONE/absolute/repo/objects/info/alternates"
printf '%s\n' '../../../../clean shared/repositories/used.git/objects' > "$CLEAN_SCAN_TWO/relative/repo/objects/info/alternates"

clean_preview=$(
    cd "$CLEAN_PROJECT"
    "$GITS" clean --scan "$CLEAN_SCAN_ONE" --scan "$CLEAN_SCAN_TWO"
)
assert_contains "$clean_preview" "used:"
assert_contains "$clean_preview" "used.git"
assert_contains "$clean_preview" "2 consumers"
assert_contains "$clean_preview" "waiting:"
assert_contains "$clean_preview" "orphan.git"
assert_contains "$clean_preview" "revived.git"
assert_contains "$clean_preview" "dry run"
assert_contains "$(cat "$CLEAN_SHARED/.gits/last-scan")" $'\tused\t'
assert_contains "$(cat "$CLEAN_SHARED/.gits/last-scan")" $'\twaiting\t'
[ -d "$CLEAN_ORPHAN_MIRROR" ] || fail "clean preview deleted an orphan mirror"

clean_early_apply=$(
    cd "$CLEAN_PROJECT"
    "$GITS" clean --apply
)
assert_contains "$clean_early_apply" "cleaned: 0 mirrors"
[ -d "$CLEAN_ORPHAN_MIRROR" ] || fail "clean deleted a mirror before the grace period"

mkdir -p "$CLEAN_SCAN_ONE/revived/repo/objects/info"
printf '%s\n' "$CLEAN_REVIVED_MIRROR/objects" > "$CLEAN_SCAN_ONE/revived/repo/objects/info/alternates"
clean_revived=$(
    cd "$CLEAN_PROJECT"
    "$GITS" clean
)
assert_contains "$clean_revived" "revived.git"
revived_key=$(printf '%s' "$CLEAN_REVIVED_MIRROR" | git hash-object --stdin)
if git config --file "$CLEAN_STATE" --get "candidate.$revived_key.firstUnused" >/dev/null 2>&1; then
    fail "clean did not reset a candidate after it became used"
fi

orphan_key=$(printf '%s' "$CLEAN_ORPHAN_MIRROR" | git hash-object --stdin)
git config --file "$CLEAN_STATE" "candidate.$orphan_key.firstUnused" "$(( $(date +%s) - 31 * 86400 ))"
clean_apply=$(
    cd "$CLEAN_PROJECT"
    "$GITS" clean --apply
)
assert_contains "$clean_apply" "eligible:"
assert_contains "$clean_apply" "deleted:"
assert_contains "$clean_apply" "cleaned: 1 mirrors"
[ ! -e "$CLEAN_ORPHAN_MIRROR" ] || fail "eligible orphan mirror was not deleted"
[ -d "$CLEAN_USED_MIRROR" ] || fail "used mirror was deleted"
git -C "$CLEAN_USED_MIRROR" cat-file -e "$used_unreachable_object"

CLEAN_BLOCKED_MIRROR="$CLEAN_SHARED/repositories/blocked.git"
git init --bare -q "$CLEAN_BLOCKED_MIRROR"
(
    cd "$CLEAN_PROJECT"
    "$GITS" clean >/dev/null
)
blocked_key=$(printf '%s' "$CLEAN_BLOCKED_MIRROR" | git hash-object --stdin)
git config --file "$CLEAN_STATE" "candidate.$blocked_key.firstUnused" "$(( $(date +%s) - 31 * 86400 ))"
mv "$CLEAN_SCAN_TWO" "$CLEAN_SCAN_TWO.offline"
missing_root_output=$(
    cd "$CLEAN_PROJECT"
    "$GITS" clean --apply 2>&1 || true
)
assert_contains "$missing_root_output" "clean scan root is unavailable"
assert_contains "$missing_root_output" "no candidate state or mirrors were changed"
[ -d "$CLEAN_BLOCKED_MIRROR" ] || fail "clean deleted a mirror after an incomplete scan"
mv "$CLEAN_SCAN_TWO.offline" "$CLEAN_SCAN_TWO"

mkdir "$CLEAN_SHARED/.gits/lock"
lock_output=$(
    cd "$CLEAN_PROJECT"
    "$GITS" clean --apply 2>&1 || true
)
assert_contains "$lock_output" "shared modules repository is locked"
rmdir "$CLEAN_SHARED/.gits/lock"

CLEAN_NEW_MIRROR="$CLEAN_SHARED/repositories/new-candidate.git"
git init --bare -q "$CLEAN_NEW_MIRROR"
mkdir -p "$CLEAN_SCAN_ONE/broken/repo/objects/info"
printf '%s\n' "$CLEAN_SHARED/repositories/missing.git/objects" > "$CLEAN_SCAN_ONE/broken/repo/objects/info/alternates"
invalid_alternate_output=$(
    cd "$CLEAN_PROJECT"
    "$GITS" clean 2>&1 || true
)
assert_contains "$invalid_alternate_output" "blocked invalid alternate"
new_key=$(printf '%s' "$CLEAN_NEW_MIRROR" | git hash-object --stdin)
if git config --file "$CLEAN_STATE" --get "candidate.$new_key.firstUnused" >/dev/null 2>&1; then
    fail "incomplete clean scan updated candidate state"
fi
rm -f "$CLEAN_SCAN_ONE/broken/repo/objects/info/alternates"

ln -s "$CLEAN_USED_MIRROR" "$CLEAN_SHARED/repositories/symlink.git"
symlink_output=$(
    cd "$CLEAN_PROJECT"
    "$GITS" clean 2>&1 || true
)
assert_contains "$symlink_output" "blocked symbolic link"
rm -f "$CLEAN_SHARED/repositories/symlink.git"

git init -q "$CLEAN_SHARED/repositories/non-bare.git"
non_bare_output=$(
    cd "$CLEAN_PROJECT"
    "$GITS" clean 2>&1 || true
)
assert_contains "$non_bare_output" "blocked non-bare shared mirror"
rm -rf "$CLEAN_SHARED/repositories/non-bare.git"

forget_output=$(
    cd "$CLEAN_PROJECT"
    "$GITS" clean --forget-scan "$CLEAN_SCAN_TWO"
)
assert_contains "$forget_output" "clean scan root forgotten"
assert_contains "$forget_output" "no mirrors were deleted"
if git config --file "$CLEAN_STATE" --get-all clean.scanRoot | grep -Fqx "$CLEAN_SCAN_TWO"; then
    fail "clean scan root was not forgotten"
fi

NO_SCAN_PROJECT="$TEST_ROOT/no-scan-project"
NO_SCAN_SHARED="$TEST_ROOT/no-scan-shared"
mkdir "$NO_SCAN_PROJECT" "$NO_SCAN_SHARED"
git -C "$NO_SCAN_PROJECT" init -q
git -C "$NO_SCAN_PROJECT" config --local gits.sharedSubmodules "$NO_SCAN_SHARED"
no_scan_output=$(
    cd "$NO_SCAN_PROJECT"
    "$GITS" clean --apply 2>&1 || true
)
assert_contains "$no_scan_output" "no clean scan roots registered"

LOCKED_INIT_PROJECT="$TEST_ROOT/locked-init-project"
mkdir "$LOCKED_INIT_PROJECT" "$CLEAN_SHARED/.gits/lock"
git -C "$LOCKED_INIT_PROJECT" init -q
locked_init_output=$(
    cd "$LOCKED_INIT_PROJECT"
    "$GITS" init "$CLEAN_SHARED" 2>&1 || true
)
assert_contains "$locked_init_output" "shared modules repository is locked"
rmdir "$CLEAN_SHARED/.gits/lock"

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
    GIT_EDITOR="$EDITOR_ACCEPT" "$GITS" admit scripts/ >/dev/null
)
assert_equals "$(git -C "$TEST_ROOT/add-project" log -1 --pretty=%s)" "update submodule: scripts"

advance_submodule "update scripts and android"
git -C "$TEST_ROOT/add-project/scripts" pull -q --ff-only
git -C "$TEST_ROOT/add-project/android" pull -q --ff-only
(
    cd "$TEST_ROOT/add-project"
    GIT_EDITOR="$EDITOR_ACCEPT" "$GITS" admit scripts android >/dev/null
)
assert_equals "$(git -C "$TEST_ROOT/add-project" log -1 --pretty=%s)" "update submodule: scripts android"

advance_submodule "update all submodules"
git -C "$TEST_ROOT/add-project/scripts" pull -q --ff-only
git -C "$TEST_ROOT/add-project/android" pull -q --ff-only
git -C "$TEST_ROOT/add-project/ios" pull -q --ff-only
(
    cd "$TEST_ROOT/add-project"
    GIT_EDITOR="$EDITOR_ACCEPT" "$GITS" admit --all >/dev/null
)
assert_equals "$(git -C "$TEST_ROOT/add-project" log -1 --pretty=%s)" "update submodule: scripts android ios"

echo "directory update" >> "$TEST_ROOT/add-project/non-submodule-directory/content.txt"
(
    cd "$TEST_ROOT/add-project"
    GIT_EDITOR="$EDITOR_ACCEPT" "$GITS" admit non-submodule-directory >/dev/null
)
assert_equals "$(git -C "$TEST_ROOT/add-project" log -1 --pretty=%s)" "feat:"

advance_submodule "mixed update"
git -C "$TEST_ROOT/add-project/ios" pull -q --ff-only
echo "root update" >> "$TEST_ROOT/add-project/root.txt"
(
    cd "$TEST_ROOT/add-project"
    GIT_EDITOR="$EDITOR_ACCEPT" "$GITS" admit . >/dev/null
)
assert_equals "$(git -C "$TEST_ROOT/add-project" log -1 --pretty=%s)" "feat:"

echo "custom update" >> "$TEST_ROOT/add-project/root.txt"
(
    cd "$TEST_ROOT/add-project"
    GIT_EDITOR="$EDITOR_SUPPLEMENT" "$GITS" admit root.txt >/dev/null
)
assert_equals "$(git -C "$TEST_ROOT/add-project" log -1 --pretty=%s)" "feat: custom detail"

echo "legacy alias update" >> "$TEST_ROOT/add-project/root.txt"
legacy_commit_output=$(
    cd "$TEST_ROOT/add-project"
    GIT_EDITOR="$EDITOR_ACCEPT" "$GITS" commit root.txt 2>&1
)
assert_contains "$legacy_commit_output" "'commit' is deprecated; use 'gits admit' instead"
assert_equals "$(git -C "$TEST_ROOT/add-project" log -1 --pretty=%s)" "feat:"

echo "previously staged" >> "$TEST_ROOT/add-project/root.txt"
git -C "$TEST_ROOT/add-project" add root.txt
echo "must be rolled back" > "$TEST_ROOT/add-project/rollback.txt"
before_interrupt=$(git -C "$TEST_ROOT/add-project" diff --cached)
if (
    cd "$TEST_ROOT/add-project"
    GIT_EDITOR="$EDITOR_INTERRUPT" "$GITS" admit rollback.txt >/dev/null 2>&1
); then
    fail "interrupted add unexpectedly succeeded"
fi
after_interrupt=$(git -C "$TEST_ROOT/add-project" diff --cached)
assert_equals "$after_interrupt" "$before_interrupt"
assert_equals "$(git -C "$TEST_ROOT/add-project" diff --cached --name-only)" "root.txt"

echo "PASS: gits tests"
