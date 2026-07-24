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

### Shell 自动补全

Homebrew Formula 会自动安装 Bash、Zsh、Fish 补全脚本。安装或升级后请重新
打开终端，再测试 Tab 补全。

如果 Zsh 尚未启用补全，可在当前会话执行：

```bash
eval "$(brew shellenv)"
autoload -Uz compinit
compinit
```

由于 `add` 和 `admit` 都是合法命令，输入 `gits ad<Tab>` 会列出两者；
输入 `gits adm<Tab>` 会直接补全为 `gits admit`。

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
gits pull scripts/
gits pull android ios
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

仅尾部 `.git` 不同的 URL 会复用同一个 mirror，例如 `../fe-system-docs` 与 `../fe-system-docs.git`。升级后再次执行 `gits init` 或 `gits pull` 会将 checkout 从旧版 raw-URL alternate 迁移到统一 mirror。

`gits init` 会按现有配置初始化顶层子模块；`gits pull` 会保持每个已初始化子模块的当前分支，只快进该分支配置的 upstream，不会隐式切换分支。进入子模块后可直接使用 `git status`、`git pull` 和正常代码修改流程。切换共享目录时会迁移同一子模块的旧 gits alternate 引用。

如果多个子模块路径指向同一个 repository URL，普通模式会分别更新和重置每个路径。共享模式下，`gits pull` 对同一中央 mirror 只 fetch 一次，随后在保持各工作区当前分支的前提下分别更新。如果 upstream 领先于 superproject 记录的 gitlink，`git status` 会将每个已更新子模块显示为修改状态，直到提交新的 gitlink。

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
gits reset scripts/            # 仅取消暂存 scripts 子模块改动
gits reset --hard android ios  # 仅丢弃并恢复指定子模块
gits status                    # 等价于 git submodule status
```

`gits config --unset` 会删除当前项目所有由 gits 管理的 alternate 引用，包括旧共享目录残留，但不会删除中央目录中的裸仓库，因为它们可能仍被其他项目使用。用户自行配置的其他 alternate 会保留。

`gits reset` 和 `gits reset --hard` 未指定路径时处理父仓库及全部子模块，也可指定一个或多个子模块。指定路径时只处理对应子模块及其 gitlink，不影响父仓库普通文件和其他子模块；路径末尾的 `/` 可省略。`gits reset --all` 和 `gits reset --hard --all` 可显式选择全部子模块。

`gits init` 会检出 superproject 记录的子模块 commit。`gits pull` 使用 `git pull --ff-only --no-recurse-submodules` 更新父仓库；未指定路径时更新全部顶层子模块，也可以通过 `gits pull scripts`、`gits pull scripts/` 或 `gits pull android ios` 只更新指定子模块。路径末尾的 `/` 可省略，`gits pull --all` 与无参数的 `gits pull` 等效。每个已初始化子模块会保持当前分支，只快进到该分支配置的 upstream；命令不会隐式 checkout 其他分支。子模块处于 detached HEAD 或当前分支没有 upstream 时会报错停止，由开发者明确选择或配置分支。尚未初始化的指定子模块只会初始化到 superproject 记录的 commit，不会自动选择分支。产生新的 gitlink 后，可检查改动并通过 `gits admit <path...>` 提交。

## Cleanup：安全清理闲置 mirror

`gits cleanup` 只会清理整个无人引用的 bare mirror，不会删除仍被 checkout 引用的 mirror 中的单个 object。

首次使用时，需要登记所有可能包含 shared-modules 消费项目的目录树。扫描根目录会规范化并持久化到中央目录的 `.gits` 元数据中，不会修改被扫描项目：

```bash
gits cleanup --append ~/Code/clobotics
gits cleanup --append ~/Code/other-projects
```

`--append` 只增加登记，不会扫描或删除 mirror。查看当前登记清单：

```bash
gits cleanup --list
```

扫描会先输出当前已登记的全部扫描范围路径，再检查各项目的 `objects/info/alternates`，将 mirror 标记为 `used`、`waiting` 或 `eligible`。首次发现无人引用的 mirror 后进入 30 天观察期。只预览时执行：

```bash
gits cleanup --dry-run
```

连续闲置至少 30 天后，缺省命令会删除 eligible mirror；`--apply` 是语义相同的显式写法：

```bash
gits cleanup
gits cleanup --apply
```

缺省命令和 `--apply` 删除前一定会重新扫描。任一扫描根目录缺失或不可读、alternate 无效、mirror 不是普通 bare repository，或者中央目录已被其他 gits 操作锁定时，命令都会 fail closed，不删除任何 mirror。共享模式下的 `gits init`、`gits pull` 和 `gits cleanup` 使用同一把中央锁。

永久停用某个扫描根目录时可执行：

```bash
gits cleanup --remove ~/Code/old-workspace
```

该命令只移除 cleanup 元数据，不会同时删除 mirror。所有使用同一 shared-modules 的项目都必须位于已登记扫描根目录下；范围之外的项目无法被发现，因此执行清理前必须通过另一个 `--append` 根目录覆盖它们。

首版以整个 mirror 为最小回收单位。只要 mirror 仍有消费者，就会完整保留，包括当前远端 refs 已不可达的 object；精确 object 级垃圾回收不在本版本范围内。

## Admit：添加并提交改动

`gits add` 保留标准 Git 子模块语义，将所有参数完整透传给 `git submodule add`：

```bash
gits add [-q|--quiet] [-b <branch>] [-f|--force] [--name <name>] \
  [--reference <repository>] [--] <repository> [<path>]
```

`admit` 表示将选中的改动接纳到项目历史中。`gits admit` 会先暂存指定路径，然后打开 Git 配置的编辑器并预填提交信息；编辑器正常关闭后创建 commit：

```bash
gits admit scripts
gits admit scripts/
gits admit scripts android
gits admit non-submodule-directory
gits admit .
```

子模块路径末尾的 `/` 会被规范化，因此 `gits admit scripts` 与 `gits admit scripts/` 等效。

`--all` 仅暂存 `.gitmodules` 中声明的全部子模块：

```bash
gits admit --all
```

如果项目包含 `scripts`、`android` 和 `ios` 三个子模块，该命令等效于：

```bash
git add scripts android ios
```

`gits admit --all` 与 `git add --all` 不同，不会自动暂存普通文件。

如果本次 commit 仅包含子模块，默认提交信息为：

```text
update submodule: scripts android ios
```

如果包含任何普通文件或目录，默认提交信息为：

```text
feat:
```

用户可以保留、替换或补充默认内容。commit 也会包含执行 `gits admit` 前已经暂存的改动。如果提交信息编辑被中断或取消，`gits` 会将暂存区完整恢复到命令执行前的状态，不会丢弃工作区改动。

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
