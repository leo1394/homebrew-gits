# gits

`gits` 是面向 Git 子模块的轻量命令行工作流。它遵循标准子模块语义，并可让多个项目复用一个中央裸仓库缓存，减少重复下载和对象存储。

## 安装

先添加 `leo1394/gits` tap，再按普通 Formula 名称安装：

```bash
brew tap leo1394/gits
brew install gits
```

tap 只需添加一次，后续安装、升级和重装都可以直接使用 `gits`。

Git 是必需依赖。macOS 上 Formula 使用系统提供的 Git，不会重复安装 Homebrew Git；Linux 上 Homebrew 会在需要时安装 Git Formula。

主分支推送后、正式 tag 发布前，可以安装 HEAD 版本：

```bash
brew install --HEAD gits
```

### 旧 shell alias 冲突

如果 `gits list` 或 `gits config` 输出 `git submodule` 的 usage，说明旧版 shell alias 或 function 覆盖了 Homebrew 可执行文件。可在当前终端执行：

```bash
unalias gits 2>/dev/null || true
unset -f gits 2>/dev/null || true
hash -r
type -a gits
```

Apple Silicon Mac 的第一条结果应为 `/opt/homebrew/bin/gits`，Intel Mac 应为 `/usr/local/bin/gits`。同时应从 shell 启动文件中删除或注释旧的 `gits` alias，再打开新终端。

## 使用

普通子模块流程不会启用共享模式：

```bash
cd /path/to/project
gits init
gits pull
```

只有在当前项目中明确传入中央目录时，才会为该项目启用共享模式：

```bash
cd /path/to/project
gits init ~/.cache/gits
```

配置写入当前项目的 `.git/config`：

```ini
[gits]
    sharedSubmodules = /Users/you/.cache/gits
```

它不会创建或读取全局 `~/.gits-config`，所以一个项目的选择不会影响其他项目。后续 `gits init`、`gits pull` 和 `gits list` 会继续使用该项目记录的中央目录。

中央目录保存按 URL 区分的裸仓库；每个项目仍保留独立的子模块工作区，并通过 Git alternates 共享中央对象。这样既能复用数据，也不会用符号链接破坏 superproject 记录的子模块提交。

`gits init`、`gits pull` 和 `gits reset` 会让顶层子模块保持在 `.gitmodules` 配置分支或远端默认分支，进入子模块后可直接使用 `git status`、`git pull` 和正常代码修改流程。切换共享目录时会迁移同一子模块的旧 gits alternate 引用。

如果多个子模块路径指向同一个 repository URL，普通模式会分别更新和重置每个路径。共享模式下，`gits pull` 对同一中央 mirror 只 fetch 一次，随后分别更新所有引用它的工作区。如果远端分支领先于 superproject 记录的 gitlink，`git status` 会将每个已更新子模块显示为修改状态，直到提交新的 gitlink。

`gits list` 会同时显示子模块路径及其在 `.gitmodules` 中声明的 URL：

```text
shared repository: disabled
android : ../clobotics-camera-sdk-android
ios : ../clobotics-camera-sdk-ios
```

子模块路径和已启用的共享仓库路径显示为绿色；`disabled` 状态及所有 `gits:` 错误信息显示为红色。

```bash
gits config                    # 查看当前项目配置
gits config ~/.cache/gits      # 为当前项目启用或更换中央目录
gits config --unset            # 为当前项目关闭共享模式
gits list                      # 查看子模块及缓存状态
gits reset                     # 取消暂存根仓库和子模块改动
gits reset --hard              # 丢弃根仓库和子模块改动
gits status                    # 等价于 git submodule status
```

`gits config --unset` 会删除当前项目所有由 gits 管理的 alternate 引用，包括旧共享目录残留，但不会删除中央目录中的裸仓库，因为它们可能仍被其他项目使用。用户自行配置的其他 alternate 会保留。

`gits init` 会检出 superproject 记录的子模块 commit。`gits pull` 使用 `git pull --ff-only` 更新父仓库，然后将每个顶层子模块推进到 `submodule.<name>.branch` 配置的远端分支；未配置 branch 时使用远端默认分支。产生新的 gitlink 后，可检查改动并通过 `gits commit <path...>` 提交。

## 添加并提交改动

`gits add` 保留标准 Git 子模块语义，将所有参数完整透传给 `git submodule add`：

```bash
gits add [-q|--quiet] [-b <branch>] [-f|--force] [--name <name>] \
  [--reference <repository>] [--] <repository> [<path>]
```

`gits commit` 会先暂存指定路径，然后打开 Git 配置的编辑器并预填提交信息；编辑器正常关闭后创建 commit：

```bash
gits commit scripts
gits commit scripts/
gits commit scripts android
gits commit non-submodule-directory
gits commit .
```

子模块路径末尾的 `/` 会被规范化，因此 `gits commit scripts` 与 `gits commit scripts/` 等效。

`--all` 仅暂存 `.gitmodules` 中声明的全部子模块：

```bash
gits commit --all
```

如果项目包含 `scripts`、`android` 和 `ios` 三个子模块，该命令等效于：

```bash
git add scripts android ios
```

`gits commit --all` 与 `git add --all` 不同，不会自动暂存普通文件。

如果本次 commit 仅包含子模块，默认提交信息为：

```text
update submodule: scripts android ios
```

如果包含任何普通文件或目录，默认提交信息为：

```text
feat:
```

用户可以保留、替换或补充默认内容。commit 也会包含执行 `gits commit` 前已经暂存的改动。如果提交信息编辑被中断或取消，`gits` 会将暂存区完整恢复到命令执行前的状态，不会丢弃工作区改动。

## 开发与发布

```bash
bash -n bin/gits tests/gits_test.sh
bash tests/gits_test.sh
brew style Formula/gits.rb
brew audit --strict gits
```

版本号同时维护在 `bin/gits`、`Formula/gits.rb` 和 `CHANGELOG.md`。Formula 固定下载版本 tag 下的脚本并校验 SHA-256，完整发布顺序和验收命令见 [`RELEASING-ZH.md`](RELEASING-ZH.md)。

## License

MIT
