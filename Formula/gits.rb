class Gits < Formula
  desc "Project-scoped Git submodule workflow with a shared repository cache"
  homepage "https://github.com/leo1394/homebrew-gits"
  url "https://raw.githubusercontent.com/leo1394/homebrew-gits/v0.2.4/bin/gits", using: :nounzip
  sha256 "ab48d5c5de8713205b4faf7785ad9fc9beb8b5fa292ae79ed54caeb4faf777b1"
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
    assert_match "gits 0.2.4", shell_output("#{bin}/gits --version")
    system "git", "init", "project"
    assert_match "disabled", shell_output("cd project && #{bin}/gits list")
  end
end
