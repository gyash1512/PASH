# Homebrew Formula for PASH
class Pash < Formula
  desc "AI-powered pre-push code review"
  homepage "https://github.com/gyash1512/PASH"
  url "https://github.com/gyash1512/PASH/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "5a5183cbd311b79d77839405aca4bb07a63e985b6bc71d4fd108cd231d4948da"
  license "MIT"

  depends_on "git"
  depends_on "curl"
  depends_on "jq"

  def install
    # The 'libexec' is a directory within the Homebrew cellar that is
    # specific to this formula. It's a good place to put all the files.
    libexec.install "pash_test.sh"
    libexec.install "review_module.sh"
    libexec.install ".pash_config"

    # The 'bin' is a directory that Homebrew adds to the user's PATH.
    # We create a symbolic link from the 'bin' to our main script in 'libexec'.
    (bin/"pash").write_env_script libexec/"pash_test.sh", :PASH_DIR => libexec
  end

  def caveats
    <<~EOS
      Thank you for installing PASH!

      To get started, you need to initialize the framework with your AI provider's details.
      Run the following command and follow the prompts:
        pash init
    EOS
  end

  test do
    # A simple test to ensure the script can be executed.
    system "#{bin}/pash", "--version"
  end
end
