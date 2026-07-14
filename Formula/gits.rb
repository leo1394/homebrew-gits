class Gits < Formula
  desc "Project-scoped Git submodule workflow with a shared repository cache"
  homepage "https://github.com/leo1394/homebrew-gits"
  url "https://raw.githubusercontent.com/leo1394/homebrew-gits/v0.2.1/bin/gits", using: :nounzip
  sha256 "985f8cb9652cd8b6efa2a6d8f00ca47d2efde25c75966560242bfbb1dd4ce169"
  license "MIT"
  head "https://github.com/leo1394/homebrew-gits.git", branch: "master"

  depends_on "git"

  def install
    if build.head?
      bin.install "bin/gits"
    else
      bin.install "gits"
    end
  end

  test do
    assert_match "gits 0.2.1", shell_output("#{bin}/gits --version")
    system "git", "init", "project"
    assert_match "disabled", shell_output("cd project && #{bin}/gits list")
  end
end
