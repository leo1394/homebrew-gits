# Changelog

## 0.1.0 - 2026-07-13

- 提供 `init`、`pull`、`reset`、`config` 和 `list` 标准子模块流程。
- 仅在显式传入共享路径时为当前项目启用中央仓库。
- 使用项目本地 Git 配置，避免共享设置泄漏到其他项目。
- 使用中央裸仓库和 Git alternates 复用子模块对象。
- 添加 Homebrew Formula、Git 安装依赖及自动化测试。
