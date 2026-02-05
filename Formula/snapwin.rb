class Snapwin < Formula
  desc "Capture screenshots of specific windows by name using ScreenCaptureKit"
  homepage "https://github.com/magarcia/snapwin"
  url "https://github.com/magarcia/snapwin/archive/refs/tags/v#{version}.tar.gz"
  # sha256 will be updated by release workflow
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"
  head "https://github.com/magarcia/snapwin.git", branch: "main"

  depends_on :macos
  depends_on macos: :sonoma # macOS 14+

  def install
    system "swiftc", "-O", "main.swift", "-o", "snapwin"
    bin.install "snapwin"
  end

  test do
    # Basic test - just check help output
    output = shell_output("#{bin}/snapwin 2>&1", 1)
    assert_match "Usage: snapwin --window", output
  end
end
