source "https://rubygems.org"

gem "bundler", ">= 2"
gem "cocoapods", ">= 1.9.1"
# Pin fastlane to 2.210.1 to avoid CI failure with "Could not install WWDR certificate".
# Although https://github.com/fastlane/fastlane/issues/20960 was fixed with 
# https://github.com/fastlane/fastlane/releases/tag/2.212.0 we still see it happening,
# sometimes. We keep pinning to 2.210.1.
gem "fastlane", "= 2.210.1" 
gem "rest-client"
gem "xcpretty"
gem "slather"

eval_gemfile("fastlane/Pluginfile")
