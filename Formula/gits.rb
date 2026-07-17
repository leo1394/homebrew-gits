class Gits < Formula
  desc "Project-scoped Git submodule workflow with a shared repository cache"
  homepage "https://github.com/leo1394/homebrew-gits"
  url "https://raw.githubusercontent.com/leo1394/homebrew-gits/v0.2.7/bin/gits", using: :nounzip
  sha256 "488b8e72548678d96c6c8173db396aebc890a24ae3994b7bcfe161cd4b53ba43"
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
  end

  test do
    assert_match "gits 0.2.7", shell_output("#{bin}/gits --version")
    assert_predicate bin/"gits", :executable?
    assert_path_exists bash_completion/"gits"
    assert_path_exists zsh_completion/"_gits"
    assert_path_exists fish_completion/"gits.fish"
    system "git", "init", "project"
    assert_match "disabled", shell_output("cd project && #{bin}/gits list")
  end
end
