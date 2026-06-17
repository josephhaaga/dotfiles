cask "opentypeless" do
  version "0.1.39"
  sha256 arm:   "cb5e889fdb102e8d095e9162f8f8aaeb3fa1974f402d4540ad6faf32ee00f6bc",
         intel: "61cb514a572554bde5e524d1dafafc95a266c05573f2a850b37103b1263f2a9c"

  on_arm do
    url "https://github.com/tover0314-w/opentypeless/releases/download/v#{version}/OpenTypeless_#{version}_aarch64.dmg",
        verified: "github.com/tover0314-w/opentypeless/"
  end

  on_intel do
    url "https://github.com/tover0314-w/opentypeless/releases/download/v#{version}/OpenTypeless_#{version}_x64.dmg",
        verified: "github.com/tover0314-w/opentypeless/"
  end

  name "OpenTypeless"
  desc "Open-source AI voice typing for desktop"
  homepage "https://www.opentypeless.com/"

  app "OpenTypeless.app"
end
