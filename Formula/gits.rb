class Gits < Formula
  desc "Project-scoped Git submodule workflow with a shared repository cache"
  homepage "https://github.com/leo1394/homebrew-gits"
  url "https://raw.githubusercontent.com/leo1394/homebrew-gits/v0.2.3/bin/gits", using: :nounzip
  sha256 "2fb5b5421b8d9e4e45a1817455a941b3cf374895f0ffb17ecb2af0d08443cc2a"
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
    assert_match "gits 0.2.3", shell_output("#{bin}/gits --version")
    system "git", "init", "project"
    assert_match "disabled", shell_output("cd project && #{bin}/gits list")
  end
end
