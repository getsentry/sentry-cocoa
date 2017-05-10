#!/usr/bin/env ruby

AUTH_TOKEN = ""
ORG_SLUG = ""
PROJECT_SLUG = ""

Dir["#{ENV["DWARF_DSYM_FOLDER_PATH"]}/*.dSYM"].each do |dsym|
cmd = "sentry-cli --auth-token #{AUTH_TOKEN} upload-dsym --org #{ORG_SLUG} --project #{PROJECT_SLUG} #{dsym}"
puts cmd
system cmd
end
