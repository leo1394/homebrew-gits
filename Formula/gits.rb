class Gits < Formula
  desc "Project-scoped Git submodule workflow with a shared repository cache"
  homepage "https://github.com/leo1394/homebrew-gits"
  url "https://raw.githubusercontent.com/leo1394/homebrew-gits/v0.2.2/bin/gits", using: :nounzip
  sha256 "5d7d4b532a38e98d9509a1f5334e8d08c2741d419f198ba1a9eeb2368f9349cb"
  license "MIT"
  head "https://github.com/leo1394/homebrew-gits.git", branch: "master"

  uses_from_macos "git"

  def install
    if build.head?
      bin.install "bin/gits"
    else
      bin.install "gits"
    end
  end

  test do
    assert_match "gits 0.2.2", shell_output("#{bin}/gits --version")
    system "git", "init", "project"
    assert_match "disabled", shell_output("cd project && #{bin}/gits list")
  end
end
