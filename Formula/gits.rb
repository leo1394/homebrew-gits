class Gits < Formula
  desc "Project-scoped Git submodule workflow with a shared repository cache"
  homepage "https://github.com/leo1394/homebrew-gits"
  url "https://raw.githubusercontent.com/leo1394/homebrew-gits/v0.2.5/bin/gits", using: :nounzip
  sha256 "15401d950d1f4b5796ac20df99a873148ab0d7def915a6dd2959b8661e96847a"
  license "MIT"
  head "https://github.com/leo1394/homebrew-gits.git", branch: "master"

  uses_from_macos "git"

  def install
    if build.head?
      bin.install "bin/gits"
    else
      bin.install "gits"
    end
    generate_completions_from_executable(bin/"gits", "completion")
  end

  test do
    assert_match "gits 0.2.5", shell_output("#{bin}/gits --version")
    assert_path_exists bash_completion/"gits"
    assert_path_exists zsh_completion/"_gits"
    assert_path_exists fish_completion/"gits.fish"
    system "git", "init", "project"
    assert_match "disabled", shell_output("cd project && #{bin}/gits list")
  end
end
