# Changelog

## 0.2.20 - 2026-09-01

- 修复从仓库子目录执行 `gits admit <path>` 时，路径被错误地按仓库根目录解析的问题。
- `gits admit --all` 仍从仓库根目录选择 `.gitmodules` 中声明的全部子模块。

## 0.2.19 - 2026-08-28

- 新增经过 SHA256 校验的 Bash 后备安装脚本，支持在 Homebrew 版本过低时直接
  安装发布版本，并在缺少 Git 时尝试通过系统包管理器安装。
- 更新中英文 README 中的 Homebrew 与 Bash 安装说明。

## 0.2.18 - 2026-08-27

- `gits version`、`--version` 和 `-v` 的第二行改为稳定的项目主页地址，不再输出版本归档地址。
- 修复编辑提交消息时使用 `:q` 或 `:q!` 未保存退出，`gits admit` 仍会提交并保留新增暂存内容的问题。

## 0.2.17 - 2026-08-27

- 顶层当前分支尚未配置 upstream、但 `origin` 已有同名分支时，`gits pull` 自动建立 tracking 后继续拉取。

## 0.2.16 - 2026-08-12

- 新增全局 `-C <path>` 选项，可从其他目录对指定 workspace 执行 gits 命令。
- `--version`、`-v` 和 `version` 现在同时输出版本号、发布日期及对应 tag 源码归档地址。
- 更新 `gits(1)` 手册与 Bash、Zsh、Fish 自动补全。

## 0.2.15 - 2026-08-12

- 将顶层帮助精简为 Git 风格概览，新增 `gits help <command>` 和 `gits <command> --help` 详细帮助。
- 对无法识别的命令给出安全转义的错误信息和最相近命令候选，并为 `help` 主题及 `version` 命令补充 Bash、Zsh、Fish 自动补全。
- 新增 `gits(1)` 手册；Homebrew Formula 从单文件发布产物生成并安装手册，同时在 CI 中验证 stable、HEAD、帮助和 man page。
- 重写中英文 README，突出项目级对象共享、独立工作区、分支保持和 fail-closed 清理，并简化安装与上手示例。

## 0.2.14 - 2026-08-10

- 修复 Ubuntu GNU `tr` 将 mirror slug 字符集中的连字符解析为反向范围，导致共享 mirror 名退化为 `-<hash>.git` 的问题。
- 增加共享 mirror 规范路径断言，覆盖 GNU/BSD `tr` 的跨平台兼容性。

## 0.2.13 - 2026-07-29

- 修复索引含 unmerged 子模块时，`gits admit --all` 在执行 `git add` 前被 `git write-tree` 中断的问题。
- `admit --all` 现在可按子模块当前 checkout 暂存并解决 gitlink conflict，同时保留原有索引恢复保障。

## 0.2.12 - 2026-07-27

- `gits cleanup` 忽略共享 `repositories` 目录中的普通 `.DS_Store` 文件，同时继续阻止其他未知条目。

## 0.2.11 - 2026-07-24

- 当前子模块分支没有 upstream 时，`gits pull` 默认拉取 `origin` 上的同名分支。
- 单个子模块更新失败不会中断后续遍历；全部模块处理完成后，命令仍以非零状态反映失败。

## 0.2.10 - 2026-07-24

- 修复 `gits pull` 会按 `.gitmodules` 配置或远端默认分支隐式切换子模块分支的问题。
- 普通模式与共享模式现在都会保持每个已初始化子模块的当前分支，只快进该分支配置的 upstream。
- 父仓库 pull 显式禁止递归子模块更新；子模块处于 detached HEAD 或当前分支没有 upstream 时安全报错，不执行分支切换。

## 0.2.9 - 2026-07-18

- 将 `gits clean` 重命名为 `gits cleanup`，并将缺省行为调整为删除满足安全条件的 eligible mirror。
- 新增 `gits cleanup --dry-run` 预览模式并保留 `--apply`。
- 使用 `--list`、`--append`、`--remove` 管理扫描范围登记，替代原 `--scan` 与 `--forget-scan`。
- `gits cleanup` 扫描时明确输出当前已登记的全部扫描范围路径。

## 0.2.8 - 2026-07-17

- 扩展 `gits pull` 支持指定一个或多个子模块路径；无参数或 `--all` 时更新全部子模块。
- 扩展 `gits reset` 和 `gits reset --hard` 支持只重置指定子模块；未指定路径时保持全量行为。

## 0.2.7 - 2026-07-17

- 移除已弃用的 `gits commit` 兼容命令，统一使用 `gits admit`。
- 移除用户可见的 `gits completion` 命令；Homebrew 仍会自动安装 Bash、Zsh、Fish 补全脚本。

## 0.2.6 - 2026-07-15
- 优化gits日志输出

## 0.2.5 - 2026-07-15

- 将交互式暂存并提交命令重命名为 `gits admit`；`gits commit` 暂时作为带弃用提示的兼容别名。
- 新增安全的 `gits clean` dry-run、扫描根登记和 30 天观察期，只删除确认没有 alternate 消费者的完整 mirror。
- 为共享模式的 `init`、`pull` 和 `clean` 增加中央目录互斥锁；扫描不完整或目录异常时禁止删除。
- 新增 Bash、Zsh、Fish 自动补全生成命令，并由 Homebrew Formula 自动安装三种补全脚本。
- 修复 raw 单文件安装后缺少可执行权限，导致 Formula 生成补全时出现 `EACCES` 的问题。

## 0.2.4 - 2026-07-14

- 将仅尾部 `.git` 不同的子模块 URL 归一为同一中央 mirror，并迁移旧版 alternate 引用。

## 0.2.3 - 2026-07-14

- 切换或关闭共享模式时清理旧 gits alternate 引用，并让顶层子模块保持在可直接开发和拉取的分支上。

## 0.2.2 - 2026-07-14

- macOS 上复用系统 Git，避免安装重复的 Homebrew Git；Linuxbrew 仍按需安装 Git Formula。
- 统一共享子模块仓库相关输出文案和终端显示样式。

## 0.2.1 - 2026-07-14

- `gits pull` 将顶层子模块推进到配置的远端分支最新提交，而不是停留在父仓库记录的旧 gitlink。

## 0.2.0 - 2026-07-14

- 添加交互式 `gits commit`，支持路径、多个路径、`.` 和仅包含全部子模块的 `--all`。
- 保留 `gits add` 对 `git submodule add` 的完整参数透传。
- 仅提交子模块时预填 `update submodule: <submodules>`，包含普通文件时预填 `feat:`。
- 在提交信息编辑被取消或中断时恢复执行命令前的暂存区。
- 为错误、禁用状态和子模块路径增加颜色，并在 `gits list` 中显示 `.gitmodules` URL。
- 同一 repository 被多个子模块路径引用时，共享模式只更新一次中央 mirror，并分别同步所有工作区。

## 0.1.0 - 2026-07-13

- 提供 `init`、`pull`、`reset`、`config` 和 `list` 标准子模块流程。
- 仅在显式传入共享路径时为当前项目启用中央仓库。
- 使用项目本地 Git 配置，避免共享设置泄漏到其他项目。
- 使用中央裸仓库和 Git alternates 复用子模块对象。
- 添加 Homebrew Formula、Git 安装依赖及自动化测试。
