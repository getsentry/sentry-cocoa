source "https://rubygems.org"

gem "bundler", ">= 2"
gem "cocoapods", ">= 1.9.1"
gem "fastlane"
gem "rest-client"

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
