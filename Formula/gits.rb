class Gits < Formula
  desc "Project-scoped Git submodule workflow with a shared repository cache"
  homepage "https://github.com/leo1394/homebrew-gits"
  url "https://raw.githubusercontent.com/leo1394/homebrew-gits/v0.2.15/bin/gits", using: :nounzip
  sha256 "07fee2752ba6cd2785d4967b8a1855ff0644ece301234b53580cca4e169e2c72"
  license "MIT"
  head "https://github.com/leo1394/homebrew-gits.git", branch: "master"

  uses_from_macos "git"

  def install
    if build.head?
      bin.install "bin/gits"
    else
      bin.install "gits"
    end
    chmod 0755, bin/"gits"
    generate_completions_from_executable(bin/"gits", "__completion")
    if build.head? || version >= "0.2.15"
      man1.mkpath
      (man1/"gits.1").write Utils.safe_popen_read(bin/"gits", "__manpage")
    end
  end

  test do
    assert_match "gits 0.2.15", shell_output("#{bin}/gits --version")
    assert_predicate bin/"gits", :executable?
    assert_path_exists bash_completion/"gits"
    assert_path_exists zsh_completion/"_gits"
    assert_path_exists fish_completion/"gits.fish"
    if build.head? || version >= "0.2.15"
      assert_path_exists man1/"gits.1"
      assert_match "manage Git submodules", (man1/"gits.1").read
    end
    system "git", "init", "project"
    assert_match "disabled", shell_output("cd project && #{bin}/gits list")
  end
end
