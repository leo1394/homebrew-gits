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
- Keeps top-level submodules on their configured or remote default branch for
  normal development commands.
- Pulls the superproject with fast-forward-only semantics and advances each
  top-level submodule to the latest commit on its configured remote branch.
- Stages selected paths and opens an editor with a context-aware default commit
  message.
- Previews and safely removes whole shared mirrors that have had no consumers
  for at least 30 days.
- Installs native Bash, Zsh, and Fish command completions through Homebrew.

## Requirements

- macOS or Linux with Homebrew
- Bash
- Git 2.31 or later

The Homebrew formula uses the Git provided by macOS. On Linux, Homebrew installs
its Git formula when needed.

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

### Shell completion

The Homebrew formula installs Bash, Zsh, and Fish completion files. After
installing or upgrading, open a new terminal before testing completion.

For Zsh, if completion is not already enabled, initialize Homebrew's shell
environment and Zsh completion once in the current session:

```bash
eval "$(brew shellenv)"
autoload -Uz compinit
compinit
```

Because both `add` and `admit` are valid commands, `gits ad<Tab>` lists both
candidates. `gits adm<Tab>` completes directly to `gits admit`.

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
gits pull scripts/
gits pull android ios
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

`gits config --unset` removes every alternate managed by gits for the current
project, including references to previous shared paths. It preserves unrelated
user-managed alternates and does not delete central mirrors that other projects
may still use.

`gits list` prints each submodule path together with its URL from `.gitmodules`:

```text
shared modules repository: disabled
android : ../clobotics-camera-sdk-android
ios : ../clobotics-camera-sdk-ios
```

Submodule paths and enabled shared-repository paths are green. The `disabled`
state and all `gits:` error messages are red.

## Clean unused shared mirrors

`gits clean` removes only complete, unused bare mirrors. It never prunes
individual objects from a mirror that is still referenced by a checkout.

First register every directory tree that may contain projects using the current
shared repository. Scan roots are canonicalized and stored under the shared
directory, not in the projects being scanned:

```bash
gits clean --scan ~/Code/company
gits clean --scan ~/Code/other-projects
```

The command scans `objects/info/alternates`, reports each mirror as `used`,
`waiting`, or `eligible`, and starts a 30-day waiting period for mirrors with no
consumers. The default command always performs a dry run:

```bash
gits clean
```

After a mirror has remained unused for at least 30 days, delete eligible
mirrors with:

```bash
gits clean --apply
```

`--apply` performs a fresh scan before deleting anything. If any registered
scan root is missing or unreadable, an alternate is invalid, a mirror is not a
normal bare repository, or the shared repository is locked, the command fails
closed and deletes nothing. Shared `gits init`, `gits pull`, and `gits clean`
operations use the same central lock.

Remove a scan root that is permanently retired with:

```bash
gits clean --forget-scan ~/Code/old-workspace
```

This only changes clean metadata and never deletes mirrors in the same command.
All projects using the shared directory must be located under the registered
scan roots. A project outside those roots cannot be discovered and therefore
must be covered by another `--scan` root before using `--apply`.

## Admit changes

`gits add` retains standard Git submodule behavior and passes all arguments
through to `git submodule add`:

```bash
gits add [-q|--quiet] [-b <branch>] [-f|--force] [--name <name>] \
  [--reference <repository>] [--] <repository> [<path>]
```

`admit` describes accepting selected changes into project history. `gits admit`
stages the requested paths, opens the Git-configured editor with a
default commit message, and creates a commit after the editor closes:

```bash
gits admit scripts
gits admit scripts/
gits admit scripts android
gits admit non-submodule-directory
gits admit .
```

A trailing slash on an exact submodule path is normalized, so
`gits admit scripts` and `gits admit scripts/` behave the same way.

Use `--all` to stage every submodule declared in `.gitmodules`:

```bash
gits admit --all
```

For a project whose submodules are `scripts`, `android`, and `ios`, this is
equivalent to:

```bash
git add scripts android ios
```

Unlike `git add --all`, `gits admit --all` does not stage non-submodule files.

If the staged commit contains only submodule entries, the editor starts with:

```text
update submodule: scripts android ios
```

If it contains any regular file or directory, the editor starts with:

```text
feat:
```

You can keep, replace, or extend the default text. The commit includes changes
that were already staged before `gits admit`. If message editing is interrupted
or cancelled, `gits` restores the index exactly to its pre-command state;
working tree changes are not discarded.

## How object sharing works

The shared directory contains one bare mirror for each distinct submodule URL.
Each project still has its own submodule working tree at the path recorded in
`.gitmodules`. The submodule checkout references the mirror's object database
through Git alternates.

URLs that differ only by a trailing `.git` suffix use the same mirror. For
example, `../fe-system-docs` and `../fe-system-docs.git` share one object store.

This design reduces repeated network transfers and object storage while
preserving normal submodule isolation. It does not replace submodule directories
with symbolic links, and it does not automatically stage the resulting gitlink
changes in the superproject.

Cleaning works at mirror granularity. A referenced mirror is preserved in full,
including objects that are not reachable from its current remote refs. This
protects checkouts that borrow the mirror through Git alternates; object-level
garbage collection is intentionally outside the scope of `gits clean`.

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
| `gits pull` | Fast-forward the superproject, then advance all submodules to their remote branches. |
| `gits pull <path...>` | Fast-forward the superproject, then advance only the selected submodules. A trailing `/` is optional. |
| `gits pull --all` | Explicitly advance all submodules; equivalent to `gits pull`. |
| `gits reset` | Unstage changes in the superproject and all initialized submodules. |
| `gits reset <path...>` | Unstage changes only for the selected submodules. A trailing `/` is optional. |
| `gits reset --hard` | Discard tracked changes and restore all recorded submodule commits. |
| `gits reset --hard <path...>` | Discard changes and restore only the selected submodules. |
| `gits reset [--hard] --all` | Explicitly reset the repository and all submodules. |
| `gits add <args...>` | Pass all arguments through to `git submodule add`. |
| `gits admit <path...>` | Stage paths, edit a default message, and create a commit. |
| `gits admit --all` | Stage all declared submodules, edit a message, and create a commit. |
| `gits config` | Show the shared path configured for the current project. |
| `gits config <shared_path>` | Enable or change shared mode for the current project. |
| `gits config --unset` | Disable shared mode and remove this project's gits-managed alternates. |
| `gits list` | Show submodules and their shared-cache state. |
| `gits clean --scan <root>` | Register a project scan root and preview mirror usage. |
| `gits clean` | Rescan registered roots and preview unused mirrors. |
| `gits clean --apply` | Delete mirrors that have remained unused for at least 30 days. |
| `gits clean --forget-scan <root>` | Remove a registered scan root without deleting mirrors. |
| `gits status` | Pass `status` through to `git submodule`. |
| `gits <args...>` | Pass other arguments through to `git submodule`. |
| `gits --version` | Print the installed version. |

`gits init` checks out the commits recorded by the superproject. `gits pull`
without paths advances each top-level submodule to the branch configured by
`submodule.<name>.branch`, or to the remote default branch when no branch is
configured. Pass one or more paths to update only those submodules; `scripts`
and `scripts/` select the same path. When this produces new gitlink values,
review them and commit them with `gits admit <path...>`.

Use `gits reset --hard` carefully: without paths it discards tracked changes in
both the superproject and initialized submodules. With paths, ordinary files in
the superproject and unselected submodules are left unchanged.

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
