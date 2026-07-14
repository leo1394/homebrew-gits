# 发布流程

## 1. 验证

```bash
bash -n bin/gits tests/gits_test.sh
bash tests/gits_test.sh
ruby -c Formula/gits.rb
brew style Formula/gits.rb
```

确认 `bin/gits`、`Formula/gits.rb` 和 `CHANGELOG.md` 中的版本一致。重新计算脚本摘要，并确认与 Formula 一致：

```bash
LC_ALL=C shasum -a 256 bin/gits
```

确认工作区只包含本次发布内容。

## 2. 发布源码

将主分支推送至 `https://github.com/leo1394/homebrew-gits`，然后创建并推送与 Formula 一致的 tag：

```bash
git tag -a v0.2.4 -m "gits 0.2.4"
git push origin master v0.2.4
```

Formula 的稳定 URL 使用该 tag 下的 `bin/gits` 单文件，并用 SHA-256 锁定内容。tag 必须在安装和审计前存在。

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

## 4. 发布检查

- 在 macOS 全新环境安装，确认 Formula 复用系统 Git，不会额外安装 Homebrew Git。
- 在 Linuxbrew 环境安装，确认 Formula 在需要时安装 Git Formula。
- 在未传路径的项目执行 `gits init`，确认 `gits.sharedSubmodules` 不存在。
- 执行 `gits init <shared_path>`，确认配置仅写入当前项目的 `.git/config`。
- 执行 `gits config --unset`，确认清除当前项目的新旧 gits alternate，保留中央 mirror 和用户自定义 alternate。
- 确认 `gits init`、`gits pull` 和 `gits reset` 后顶层子模块位于配置分支或远端默认分支。
- 用两个项目复用同一 `<shared_path>`，确认中央目录只有一份对应裸仓库，并且两个项目的子模块工作区相互独立。
- 确认仅尾部 `.git` 不同的两个 URL 复用同一 mirror，并清理 checkout 中旧版 alternate 引用。
