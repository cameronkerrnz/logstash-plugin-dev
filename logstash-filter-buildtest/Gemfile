# Implant this into a new plugin; otherwise you'll find that it pulls in versions
# of logstash-devutils and logstash-core that are much too old.
#
# The plugin generated doesn't (2021-05-27, Logstash 7.13) add this completely.
#
# ref: https://github.com/elastic/logstash/issues/9083

source 'https://rubygems.org'

gemspec

logstash_path = ENV["LOGSTASH_PATH"] || "../../logstash"
use_logstash_source = ENV["LOGSTASH_SOURCE"] && ENV["LOGSTASH_SOURCE"].to_s == "1"

if Dir.exist?(logstash_path) && use_logstash_source
  gem 'logstash-core', :path => "#{logstash_path}/logstash-core"
  gem 'logstash-core-plugin-api', :path => "#{logstash_path}/logstash-core-plugin-api"
end
