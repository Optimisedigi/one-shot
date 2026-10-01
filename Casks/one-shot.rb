cask "one-shot" do
  version "0.1.0"
  sha256 "eb9aae24e7bd98cf25aaaa29fd853f0aac04ae99e5b24c6f1b034b15659acb2e"

  url "https://github.com/Optimisedigi/one-shot/releases/download/v#{version}/OneShot-#{version}-macOS.dmg"
  name "One Shot"
  desc "Menu bar screenshot and annotation tool"
  homepage "https://github.com/Optimisedigi/one-shot"

  depends_on macos: :ventura

  app "One Shot.app"

  zap trash: "~/Library/Preferences/local.oneshot.app.plist"
end
