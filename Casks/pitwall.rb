cask "pitwall" do
  version "1.0.0"
  sha256 :no_check

  url "https://github.com/GeorgeQLe/pitwall/releases/download/v#{version}/Pitwall-#{version}.dmg"
  name "Pitwall"
  desc "Menu bar app for pacing AI coding subscriptions"
  homepage "https://github.com/GeorgeQLe/pitwall"

  app "Pitwall.app"

  zap trash: [
    "~/Library/Application Support/Pitwall",
    "~/Library/Preferences/com.pitwall.app.plist",
  ]
end
