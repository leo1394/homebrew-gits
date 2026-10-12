#!/bin/bash

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
GITS="$ROOT/bin/gits"
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/gits-commit-graph-test.XXXXXX")
TEST_ROOT=$(cd "$TEST_ROOT" && pwd -P)
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

export HOME="$TEST_ROOT/home"
export GIT_CONFIG_NOSYSTEM=1
export GIT_ALLOW_PROTOCOL=file
mkdir -p "$HOME"
git config --global user.name "gits test"
git config --global user.email "gits@example.invalid"
git config --global init.defaultBranch main
git config --global protocol.file.allow always

mkdir "$TEST_ROOT/source"
git -C "$TEST_ROOT/source" init -q
echo "base" > "$TEST_ROOT/source/content.txt"
git -C "$TEST_ROOT/source" add content.txt
git -C "$TEST_ROOT/source" commit -qm "base"
git clone -q --bare "$TEST_ROOT/source" "$TEST_ROOT/origin.git"

mkdir "$TEST_ROOT/project"
git -C "$TEST_ROOT/project" init -q
git -C "$TEST_ROOT/project" submodule add -q "$TEST_ROOT/origin.git" "modules/shared module"
git -C "$TEST_ROOT/project" commit -qm "add submodule"

checkout="$TEST_ROOT/project/modules/shared module"
head=$(git -C "$checkout" rev-parse HEAD)
info=$(git -C "$checkout" rev-parse --path-format=absolute --git-path objects/info)

for layout in single split; do
    old_base="$TEST_ROOT/$layout old cache"
    new_base="$TEST_ROOT/$layout new cache"
    "$GITS" -C "$TEST_ROOT/project" init "$old_base" > "$TEST_ROOT/init.out" 2>&1
    old_objects=$(cat "$info/alternates")
    old_mirror=$(dirname "$old_objects")
    tree=$(git -C "$old_mirror" rev-parse 'HEAD^{tree}')
    ghost=$(git -C "$old_mirror" commit-tree "$tree" -p "$head" -m "old mirror only: $layout")
    git -C "$checkout" update-ref refs/gits-test/ghost "$ghost"
    if [ "$layout" = split ]; then
        git -C "$checkout" commit-graph write --reachable --split=replace
        graph="$info/commit-graphs/commit-graph-chain"
    else
        git -C "$checkout" commit-graph write --reachable
        graph="$info/commit-graph"
    fi
    git -C "$checkout" commit-graph verify
    graph_before=$(shasum "$graph")

    # An unchanged alternate must keep the valid cache, even if the mirror fetches again.
    "$GITS" -C "$TEST_ROOT/project" init "$old_base" > "$TEST_ROOT/init.out" 2>&1
    [ "$(shasum "$graph")" = "$graph_before" ] || fail "unchanged alternate discarded $layout graph"
    git -C "$checkout" update-ref -d refs/gits-test/ghost

    # The new mirror has all active history, but not the old mirror's unreferenced commit.
    "$GITS" -C "$TEST_ROOT/project" init "$new_base" > "$TEST_ROOT/init.out" 2>&1
    if ! git -C "$checkout" commit-graph verify > "$TEST_ROOT/verify.out" 2>&1; then
        cat "$TEST_ROOT/verify.out" >&2
        fail "alternate migration retained an invalid $layout commit-graph"
    fi
    [ ! -e "$info/commit-graph" ] || fail "migration retained single-file graph"
    [ ! -e "$info/commit-graphs" ] || fail "migration retained split graph"
    [ "$(git -C "$checkout" rev-parse HEAD)" = "$head" ] || fail "migration changed HEAD"
    git -C "$checkout" merge-base HEAD origin/main > /dev/null
    git -C "$checkout" merge --ff-only origin/main > /dev/null
    git -C "$checkout" fsck --no-dangling > /dev/null
    echo "PASS: $layout graph invalidated on alternate migration"
done

# Removing a managed alternate also invalidates caches, preserving other alternates and local work.
git -C "$checkout" repack -a -d
unrelated="$TEST_ROOT/user mirror.git"
git init -q --bare "$unrelated"
printf '%s\n' "$unrelated/objects" >> "$info/alternates"
git -C "$checkout" commit-graph write --reachable
git -C "$checkout" commit-graph write --reachable --split=replace
echo "uncommitted change" >> "$checkout/content.txt"
status_before=$(git -C "$checkout" status --porcelain)
"$GITS" -C "$TEST_ROOT/project" config --unset > "$TEST_ROOT/unset.out" 2>&1
[ "$(cat "$info/alternates")" = "$unrelated/objects" ] || fail "unrelated alternate was removed"
[ ! -e "$info/commit-graph" ] || fail "unset retained single-file graph"
[ ! -e "$info/commit-graphs" ] || fail "unset retained split graph"
[ "$(git -C "$checkout" status --porcelain)" = "$status_before" ] || fail "unset changed local work"
git -C "$checkout" commit-graph verify
git -C "$checkout" fsck --no-dangling > /dev/null

echo "PASS: gits commit-graph tests"
