class Gits < Formula
  desc "Project-scoped Git submodule workflow with a shared repository cache"
  homepage "https://github.com/leo1394/homebrew-gits"
  url "https://raw.githubusercontent.com/leo1394/homebrew-gits/v0.1.0/bin/gits", using: :nounzip
  version "0.1.0"
  sha256 "9c99ed0a0c9e86221379a7ef20e7a5e392bddb78210aadfe662f876d7b4384e0"
  license "MIT"
  head "https://github.com/leo1394/homebrew-gits.git", branch: "main"

  depends_on "git"

  def install
    if build.head?
      bin.install "bin/gits"
    else
      bin.install "gits"
    end
  end

  test do
    assert_match "gits 0.1.0", shell_output("#{bin}/gits --version")
    system "git", "init", "project"
    assert_match "shared repository: disabled", shell_output("cd project && #{bin}/gits list")
  end
end
