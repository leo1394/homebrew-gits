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
- Pulls the superproject with fast-forward-only semantics and checks out the
  submodule commits recorded by the superproject.

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

## How object sharing works

The shared directory contains one bare mirror for each distinct submodule URL.
Each project still has its own submodule working tree at the path recorded in
`.gitmodules`. The submodule checkout references the mirror's object database
through Git alternates.

This design reduces repeated network transfers and object storage while
preserving normal submodule isolation. It does not replace submodule directories
with symbolic links, and it does not change the submodule commit recorded by the
superproject.

## Commands

| Command | Description |
| --- | --- |
| `gits init` | Synchronize and initialize submodules without enabling shared mode. |
| `gits init <shared_path>` | Enable shared mode for this project, then initialize submodules. |
| `gits pull` | Run `git pull --ff-only`, then synchronize and update submodules. |
| `gits reset` | Unstage changes in the superproject and initialized submodules. |
| `gits reset --hard` | Discard tracked changes and restore recorded submodule commits. |
| `gits config` | Show the shared path configured for the current project. |
| `gits config <shared_path>` | Enable or change shared mode for the current project. |
| `gits config --unset` | Disable shared mode for the current project. |
| `gits list` | Show submodules and their shared-cache state. |
| `gits status` | Pass `status` through to `git submodule`. |
| `gits <args...>` | Pass other arguments through to `git submodule`. |
| `gits --version` | Print the installed version. |

`gits pull` deliberately updates each submodule to the commit recorded by the
superproject. It does not advance submodules to the latest commit on their remote
branches.

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
