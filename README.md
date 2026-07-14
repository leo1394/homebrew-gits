# gits

`gits` 是面向 Git 子模块的轻量命令行工作流。它遵循标准子模块语义，并可让多个项目复用一个中央裸仓库缓存，减少重复下载和对象存储。

## 安装

先添加 `leo1394/gits` tap，再按普通 Formula 名称安装：

```bash
brew tap leo1394/gits
brew install gits
```

tap 只需添加一次，后续安装、升级和重装都可以直接使用 `gits`。

Git 是必需依赖。Formula 声明了 `depends_on "git"`，因此 Homebrew 会在需要时先安装 Git，再安装 `gits`。

主分支推送后、正式 tag 发布前，可以安装 HEAD 版本：

```bash
brew install --HEAD gits
```

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

```bash
gits config                    # 查看当前项目配置
gits config ~/.cache/gits      # 为当前项目启用或更换中央目录
gits config --unset            # 为当前项目关闭共享模式
gits list                      # 查看子模块及缓存状态
gits reset                     # 取消暂存根仓库和子模块改动
gits reset --hard              # 丢弃根仓库和子模块改动
gits status                    # 等价于 git submodule status
```

`gits pull` 使用 `git pull --ff-only`，随后将子模块更新到 superproject 记录的提交，不会擅自把子模块推进到远端分支最新提交。

## 开发与发布

```bash
bash -n bin/gits tests/gits_test.sh
bash tests/gits_test.sh
brew style Formula/gits.rb
brew audit --strict gits
```

版本号同时维护在 `bin/gits`、`Formula/gits.rb` 和 `CHANGELOG.md`。Formula 固定下载 `v0.1.0` tag 下的脚本并校验 SHA-256，完整发布顺序和验收命令见 [`RELEASING.md`](RELEASING.md)。

## License

MIT
