# Releasing gits

This document describes the complete release process for the
`leo1394/homebrew-gits` tap. Run all commands from the repository root unless a
step says otherwise.

## Release model

The stable Homebrew formula installs a single tagged file:

```text
https://raw.githubusercontent.com/leo1394/homebrew-gits/vX.Y.Z/bin/gits
```

The formula locks that file with SHA-256. Homebrew infers the version from the
`vX.Y.Z` component of the URL, so the formula must not contain a redundant
`version "X.Y.Z"` declaration.

The release tag must be immutable. Never move, delete, or recreate a published
tag. If a released artifact is wrong, publish a new patch version.

## Prerequisites

- Push access to `git@github.com:leo1394/homebrew-gits.git`
- Homebrew, Bash, Ruby, Git, `curl`, and `shasum`
- A clean `master` branch synchronized with `origin/master`
- The public GitHub repository and its CI checks available

Confirm the starting state:

```bash
git switch master
git pull --ff-only origin master
git status --short
```

`git status --short` must produce no output before preparing the release.

## 1. Prepare the version

Choose the next semantic version. The examples below use `0.2.5`:

```bash
VERSION=0.2.5
TAG="v${VERSION}"
```

Update all version-specific locations:

1. Set `VERSION` in `bin/gits` and `VERSION.txt`.
2. Change the tag in the stable URL in `Formula/gits.rb`.
3. Update the expected version in the formula test and shell tests.
4. Add the release notes and date to `CHANGELOG.md`.

Do not add an explicit `version` line to the formula. The tagged URL provides
the version.

Calculate the checksum of the exact script being released:

```bash
LC_ALL=C shasum -a 256 bin/gits
```

Put the resulting hexadecimal digest in the `sha256` field in
`Formula/gits.rb`.

## 2. Run local checks

Check shell and Ruby syntax:

```bash
bash -n bin/gits tests/gits_test.sh
ruby -c Formula/gits.rb
```

Run the behavior tests and Homebrew style check:

```bash
bash tests/gits_test.sh
brew style Formula/gits.rb
```

Confirm that the formula checksum matches the local script:

```bash
FORMULA_SHA=$(sed -n 's/^  sha256 "\([0-9a-f]*\)"/\1/p' Formula/gits.rb)
SCRIPT_SHA=$(LC_ALL=C shasum -a 256 bin/gits | awk '{print $1}')
test "$FORMULA_SHA" = "$SCRIPT_SHA"
```

Review the complete release diff:

```bash
git diff --check
git diff
git status --short
```

Only the intended release files should be changed.

## 3. Commit and publish the tag

Commit the prepared release:

```bash
git add bin/gits VERSION.txt Formula/gits.rb tests/gits_test.sh CHANGELOG.md
git commit -m "Release gits ${VERSION}"
git push origin master
```

Create an annotated tag on that exact commit and push it:

```bash
git tag -a "$TAG" -m "gits ${VERSION}"
git push origin "$TAG"
```

The tag must exist before Homebrew can install or audit the new stable URL. A
separate GitHub Release and binary asset are not required by the Homebrew
formula; the tagged `bin/gits` file is the release artifact.

## 4. Verify the published artifact

Calculate the checksum from the immutable tagged URL:

```bash
curl -fsSL \
  "https://raw.githubusercontent.com/leo1394/homebrew-gits/${TAG}/bin/gits" |
  LC_ALL=C shasum -a 256
```

The result must exactly match the `sha256` value in `Formula/gits.rb`.

Also confirm the tagged version directly:

```bash
curl -fsSL \
  "https://raw.githubusercontent.com/leo1394/homebrew-gits/${TAG}/bin/gits" |
  bash -s -- --version
```

Expected output for the example release:

```text
gits 0.2.5
```

## 5. Verify the Homebrew tap

Refresh the tap so Homebrew audits the published formula rather than a cached
copy:

```bash
brew tap leo1394/gits
brew update
brew audit --strict gits
```

Test a fresh installation when `gits` is not installed:

```bash
brew install --build-from-source gits
brew test gits
gits --version
```

If an older version is already installed, use:

```bash
brew reinstall --build-from-source gits
brew test gits
gits --version
```

Confirm that the generated completion files are installed and linked:

```bash
test -e "$(brew --prefix)/etc/bash_completion.d/gits"
test -e "$(brew --prefix)/share/zsh/site-functions/_gits"
test -e "$(brew --prefix)/share/fish/vendor_completions.d/gits.fish"
```

Open a new Zsh session and verify that `gits adm<Tab>` completes to
`gits admit`. `gits ad<Tab>` must display both `add` and `admit`; removed
commands must not appear as candidates.

Confirm that Homebrew resolves the formula and dependency correctly:

```bash
brew info gits
brew deps gits
```

On macOS, the dependency list should not include Homebrew Git. On Linux,
Homebrew should resolve Git as a dependency through `uses_from_macos`.

## 6. Run functional acceptance checks

In disposable Git repositories, verify all of the following:

- `gits init` initializes submodules without creating
  `gits.sharedSubmodules`.
- `gits init <shared_path>` stores the canonical path only in the current
  repository's `.git/config`.
- Two projects using the same shared path reuse one bare mirror for the same
  submodule URL while retaining independent submodule working trees.
- Submodule URLs that differ only by a trailing `.git` suffix reuse the same
  mirror and migrate legacy alternate references.
- `gits pull` fast-forwards the superproject without recursive submodule
  checkout, preserves each initialized submodule's current branch, and
  fast-forwards that branch to its configured upstream.
- A detached submodule or a current branch without an upstream makes
  `gits pull` fail without switching branches or changing its commit.
- `gits config --unset` removes this project's gits-managed alternates without
  deleting shared mirrors or unrelated user-managed alternates.
- `gits cleanup --append <root>` persists the canonical scan root without
  scanning or deleting mirrors; `--list` reports all registered roots and
  `--remove <root>` removes one registration without deleting mirrors.
- `gits cleanup --dry-run` previews without deleting; `gits cleanup` and
  `gits cleanup --apply` rescan every registered root and delete only mirrors
  that have remained unused for at least 30 days.
- Missing roots, invalid alternates, central lock conflicts, symbolic links,
  and non-bare repository entries cause cleanup to fail without deleting mirrors.
- Referenced mirrors retain unreachable objects; cleanup does not run object-level
  garbage collection.
- The Formula installs non-empty Bash, Zsh, and Fish completion files, and the
  generated command candidates exclude removed commands.
- `gits init` attaches top-level submodules for normal development; `gits pull`
  preserves whichever branch is currently checked out.
- No global `~/.gits-config` file is created.

The automated test suite covers these behaviors:

```bash
bash tests/gits_test.sh
```

## 7. Complete the release

Confirm that GitHub CI passed for both the release commit and tag. Then record
the published version and checksum in the release notes or maintenance log.

For the next release, repeat this process with a new version and a new tag.
Never alter the contents behind an existing stable URL.
