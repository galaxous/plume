# typed: false
# frozen_string_literal: true

# Homebrew formula for Plume CLI (plumectl).
# Install (from this repo):
#   brew install --formula ./packaging/homebrew/plumectl.rb
# Or after publishing a tap (see docs/operations/release.md):
#   brew tap galaxous/plume
#   brew install plumectl
#
# On each GitHub release: update `url`/`version`/`sha256` (shasum -a 256 of the tag tarball).

# Plume Laravel ops CLI — installs plumectl (+ plume alias).
class Plumectl < Formula
  desc "Plume — Laravel local ops CLI (native / docker-lite / laradock-bridge)"
  homepage "https://github.com/galaxous/plume"
  url "https://github.com/galaxous/plume/archive/refs/tags/v0.3.0.tar.gz"
  version "0.3.0"
  # Replace with real digest after the first GitHub Release exists:
  #   curl -sL "https://github.com/galaxous/plume/archive/refs/tags/v0.3.0.tar.gz" | shasum -a 256
  sha256 :no_check
  license "MIT"
  head "https://github.com/galaxous/plume.git", branch: "main"

  def install
    # Keep bin/ + lib/ + VERSION + templates layout so symlink resolve works.
    libexec.install Dir["*"]
    bin.install_symlink libexec/"bin/plumectl"
    bin.install_symlink libexec/"bin/plumectl" => "plume"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/plumectl version")
  end
end
