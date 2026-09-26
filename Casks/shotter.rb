cask "shotter" do
  version "0.1.0"
  sha256 "969e5d31dd38580bc101b1ecddacaa61934f28e1f0d36055a6dd5cca71230406"

  url "https://github.com/Optimisedigi/one-shot/releases/download/v#{version}/Shotter-#{version}-macOS.dmg"
  name "Shotter"
  desc "Menu bar screenshot and annotation tool"
  homepage "https://github.com/Optimisedigi/one-shot"

  depends_on macos: :ventura

  app "Shotter.app"

  zap trash: "~/Library/Preferences/local.shotter.app.plist"
end
