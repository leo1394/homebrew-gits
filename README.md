# gits

`gits` is a lightweight Git submodule workflow with optional, project-scoped
object sharing. It keeps standard Git submodule behavior while allowing multiple
projects to reuse a central cache of bare repositories.

Shared mode is never enabled globally or implicitly. It is enabled for the
current project only when you explicitly provide a shared path.

## Features

- Initializes and updates standard Git submodules.
- Enables a central shared repository cache only for explicitly configured
  projects.
- Stores the shared-path setting in the current repository's local Git config.
- Keeps an independent submodule checkout in every project.
- Reuses Git objects through bare mirrors and Git alternates, without symlinks.
- Pulls the superproject with fast-forward-only semantics and advances each
  top-level submodule to the latest commit on its configured remote branch.
- Stages selected paths and opens an editor with a context-aware default commit
  message.

## Requirements

- macOS or Linux with Homebrew
- Bash
- Git 2.31 or later

The Homebrew formula declares Git as a dependency. If the Homebrew Git formula
is not already installed, Homebrew installs it before `gits`.

## Installation

Add the tap once, then install the formula by its short name:

```bash
brew tap leo1394/gits
brew install gits
```

The fully qualified formula name is `leo1394/gits/gits`, but it is not needed
after the tap has been added.

To upgrade or remove `gits`:

```bash
brew upgrade gits
brew uninstall gits
```

Verify the installation:

```bash
gits --version
```

### Legacy shell alias conflict

If `gits list` or `gits config` prints the `git submodule` usage text, an older
shell alias or function is shadowing the Homebrew executable. Remove the legacy
definition from the current shell and refresh command lookup:

```bash
unalias gits 2>/dev/null || true
unset -f gits 2>/dev/null || true
hash -r
type -a gits
```

The first result should be `/opt/homebrew/bin/gits` on Apple Silicon or
`/usr/local/bin/gits` on Intel macOS. Also remove or comment out the old `gits`
alias in shell startup files before opening a new terminal.

## Quick start

### Standard submodule mode

Run `init` without a path to use normal Git submodule behavior. This does not
enable shared mode:

```bash
cd /path/to/project
gits init
gits pull
```

### Project-scoped shared mode

Pass a directory explicitly to enable shared mode for the current project:

```bash
cd /path/to/project
gits init ~/.cache/gits
```

The canonical path is stored in the current repository's `.git/config`:

```ini
[gits]
    sharedSubmodules = /Users/you/.cache/gits
```

No global `~/.gits-config` file is created or read. Configuring one project does
not affect any other project. Later `gits init`, `gits pull`, and `gits list`
commands in that project continue to use the recorded shared path.

To inspect, change, or disable the project setting:

```bash
gits config
gits config /another/shared/path
gits config --unset
```

`gits list` prints each submodule path together with its URL from `.gitmodules`:

```text
shared repository: disabled
android : ../clobotics-camera-sdk-android
ios : ../clobotics-camera-sdk-ios
```

Submodule paths and enabled shared-repository paths are green. The `disabled`
state and all `gits:` error messages are red.

## Stage and commit changes

`gits add` retains standard Git submodule behavior and passes all arguments
through to `git submodule add`:

```bash
gits add [-q|--quiet] [-b <branch>] [-f|--force] [--name <name>] \
  [--reference <repository>] [--] <repository> [<path>]
```

`gits commit` stages the requested paths, opens the Git-configured editor with a
default commit message, and creates a commit after the editor closes:

```bash
gits commit scripts
gits commit scripts/
gits commit scripts android
gits commit non-submodule-directory
gits commit .
```

A trailing slash on an exact submodule path is normalized, so
`gits commit scripts` and `gits commit scripts/` behave the same way.

Use `--all` to stage every submodule declared in `.gitmodules`:

```bash
gits commit --all
```

For a project whose submodules are `scripts`, `android`, and `ios`, this is
equivalent to:

```bash
git add scripts android ios
```

Unlike `git add --all`, `gits commit --all` does not stage non-submodule files.

If the staged commit contains only submodule entries, the editor starts with:

```text
update submodule: scripts android ios
```

If it contains any regular file or directory, the editor starts with:

```text
feat:
```

You can keep, replace, or extend the default text. The commit includes changes
that were already staged before `gits commit`. If message editing is interrupted
or cancelled, `gits` restores the index exactly to its pre-command state;
working tree changes are not discarded.

## How object sharing works

The shared directory contains one bare mirror for each distinct submodule URL.
Each project still has its own submodule working tree at the path recorded in
`.gitmodules`. The submodule checkout references the mirror's object database
through Git alternates.

This design reduces repeated network transfers and object storage while
preserving normal submodule isolation. It does not replace submodule directories
with symbolic links, and it does not automatically stage the resulting gitlink
changes in the superproject.

If multiple submodule paths use the same repository URL, standard mode updates
and resets every path independently. In shared mode, `gits pull` fetches the
central mirror only once per repository, then updates every checkout that points
to it. If the remote branch is ahead of the recorded gitlink, `git status` shows
each updated submodule as modified until you commit the new gitlinks.

## Commands

| Command | Description |
| --- | --- |
| `gits init` | Synchronize and initialize submodules without enabling shared mode. |
| `gits init <shared_path>` | Enable shared mode for this project, then initialize submodules. |
| `gits pull` | Fast-forward the superproject, then advance submodules to their remote branches. |
| `gits reset` | Unstage changes in the superproject and initialized submodules. |
| `gits reset --hard` | Discard tracked changes and restore recorded submodule commits. |
| `gits add <args...>` | Pass all arguments through to `git submodule add`. |
| `gits commit <path...>` | Stage paths, edit a default message, and create a commit. |
| `gits commit --all` | Stage all declared submodules, edit a message, and create a commit. |
| `gits config` | Show the shared path configured for the current project. |
| `gits config <shared_path>` | Enable or change shared mode for the current project. |
| `gits config --unset` | Disable shared mode for the current project. |
| `gits list` | Show submodules and their shared-cache state. |
| `gits status` | Pass `status` through to `git submodule`. |
| `gits <args...>` | Pass other arguments through to `git submodule`. |
| `gits --version` | Print the installed version. |

`gits init` checks out the commits recorded by the superproject. `gits pull`
instead advances each top-level submodule to the branch configured by
`submodule.<name>.branch`, or to the remote default branch when no branch is
configured. When this produces new gitlink values, review them and commit them
with `gits commit <path...>`.

Use `gits reset --hard` carefully: it discards tracked changes in both the
superproject and initialized submodules.

## Development

Run the local checks from the repository root:

```bash
bash -n bin/gits tests/gits_test.sh
bash tests/gits_test.sh
ruby -c Formula/gits.rb
brew style Formula/gits.rb
```

For the complete release and tap verification procedure, see
[`RELEASING.md`](RELEASING.md).

## License

This project is licensed under the MIT License. See [`LICENSE`](LICENSE).
