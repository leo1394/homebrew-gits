# Changelog

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
