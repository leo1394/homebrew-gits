# Changelog

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
