# Homebrew cask for Whereabouts
#
# Host this file in a personal tap repo: github.com/USERNAME/homebrew-whereabouts
#   Casks/whereabouts.rb
#
# Install:
#   brew install --cask USERNAME/whereabouts/whereabouts
#
# To update after a new release:
#   1. Replace `version` with the new version string.
#   2. Replace `sha256` with the SHA256 printed in the GitHub Actions release summary.

cask "whereabouts" do
  version "1.0.0"
  sha256 "16608565910d15854eefebf4210f9593c43f713938a4087e88a5f1d425e13d86"

  url "https://github.com/zekevh/Whereabouts/releases/download/v#{version}/Whereabouts-#{version}.dmg"

  name "Whereabouts"
  desc "macOS menu bar app showing your public IP location and VPN status"
  homepage "https://zvh.io"

  app "Whereabouts.app"

  caveats <<~EOS
    Whereabouts is not notarized. On first launch, right-click the app and select "Open",
    then confirm in the dialog that appears.

    Alternatively, remove the quarantine attribute:
      sudo xattr -d com.apple.quarantine /Applications/Whereabouts.app
  EOS
end
