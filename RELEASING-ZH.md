# 发布流程

## 1. 准备并验证

从父工作区运行共享发布工具，由它同步 `bin/gits` 中的 `VERSION`、
`VERSION_DATE`、`VERSION.txt`、Formula、测试和摘要：

```bash
VERSION=X.Y.Z
(cd .. && ./publish.sh --target homebrew-gits --version "$VERSION" --prepare)
```

`gits --version` 是发布协议的一部分，必须准确输出两行：

```text
gits version X.Y.Z (YYYY-MM-DD)
https://github.com/leo1394/homebrew-gits/archive/refs/tags/vX.Y.Z.tar.gz
```

```bash
bash -n bin/gits tests/gits_test.sh
bash tests/gits_test.sh
ruby -c Formula/gits.rb
brew style Formula/gits.rb .github/workflows/ci.yml
bin/gits __manpage | mandoc -Tlint
```

确认 `bin/gits`、`VERSION.txt`、`Formula/gits.rb`、测试和 `CHANGELOG.md` 中的版本和日期一致。重新计算脚本摘要，并确认与 Formula 一致：

```bash
LC_ALL=C shasum -a 256 bin/gits
```

确认工作区只包含本次发布内容。

## 2. 发布源码

提交并推送准备结果后，从父工作区创建并推送与 Formula 一致的 annotated tag：

```bash
git push origin master
(cd .. && ./publish.sh --target homebrew-gits --version "$VERSION" --apply)
```

共享发布工具会先确认工作树干净、`HEAD` 与 `origin/master` 一致，并确认
本地和远程均不存在同名 tag。

Formula 的稳定 URL 使用该 tag 下的 `bin/gits` 单文件，并用 SHA-256 锁定内容。tag 必须在安装和审计前存在。
同一脚本通过内部 `__manpage` 指令生成手册，Formula 将其安装为 `gits.1`，无需增加第二个发布产物。

## 3. 验证 tap

验证发布时先确保 `leo1394/gits` tap 已添加，再使用简短 Formula 名称执行检查：

```bash
brew tap leo1394/gits
brew update
brew audit --strict gits
brew install --build-from-source gits
brew test gits
gits --version
```

确认 Formula 生成的三种补全文件已经安装并链接：

```bash
test -e "$(brew --prefix)/etc/bash_completion.d/gits"
test -e "$(brew --prefix)/share/zsh/site-functions/_gits"
test -e "$(brew --prefix)/share/fish/vendor_completions.d/gits.fish"
MANPATH="$(brew --prefix)/share/man" man -w gits
```

重新打开 Zsh，确认 `gits adm<Tab>` 直接补全为 `gits admit`，
`gits ad<Tab>` 同时列出 `add` 和 `admit`，且已移除命令不会成为候选。

## 4. 发布检查

- 在 macOS 全新环境安装，确认 Formula 复用系统 Git，不会额外安装 Homebrew Git。
- 在 Linuxbrew 环境安装，确认 Formula 在需要时安装 Git Formula。
- 在未传路径的项目执行 `gits init`，确认 `gits.sharedSubmodules` 不存在。
- 执行 `gits init <shared_path>`，确认配置仅写入当前项目的 `.git/config`。
- 执行 `gits config --unset`，确认清除当前项目的新旧 gits alternate，保留中央 mirror 和用户自定义 alternate。
- 确认 `gits pull` 保持每个已初始化子模块的当前分支，并只快进当前分支的 upstream。
- 确认当前分支没有 upstream 时，`gits pull` 默认拉取 `origin` 上的同名分支。
- 确认一个子模块处于 detached HEAD 或云端不存在同名分支时，该模块报错且不切换分支，同时后续子模块仍会继续更新，遍历完成后命令返回失败。
- 用两个项目复用同一 `<shared_path>`，确认中央目录只有一份对应裸仓库，并且两个项目的子模块工作区相互独立。
- 确认仅尾部 `.git` 不同的两个 URL 复用同一 mirror，并清理 checkout 中旧版 alternate 引用。
- 执行 `gits cleanup --append <root>`，确认只保存规范化扫描根，不扫描或删除 mirror；确认 `--list` 输出全部登记，`--remove <root>` 只删除登记。
- 执行 `gits cleanup --dry-run` 确认只预览；确认无人引用 mirror 满 30 天后，`gits cleanup` 和 `gits cleanup --apply` 二次扫描仍无人引用时才删除。
- 确认扫描根缺失、alternate 无效、锁冲突、符号链接或非 bare mirror 会阻止本次全部删除。
- 确认普通 `repositories/.DS_Store` 文件会被忽略，其他未知隐藏条目仍会阻止 cleanup。
- 确认仍被引用的 mirror 及其中 unreachable object 均被保留。
- 确认 Formula 安装的 Bash、Zsh、Fish 补全文件非空，且补全候选不包含已移除命令。
- 确认 `gits help COMMAND` 可在仓库外使用，拼写错误会给出有效近似命令，并且 `man gits` 可以找到 Formula 安装的手册。
- 确认 merge conflict 中执行 `gits admit --all` 会暂存所有已声明的 unmerged 子模块并完成提交，同时保留失败或中断时的索引恢复。
