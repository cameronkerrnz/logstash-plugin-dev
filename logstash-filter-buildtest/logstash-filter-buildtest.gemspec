Gem::Specification.new do |s|
    s.name          = 'logstash-filter-buildtest'
    s.version       = '0.1.0'
    s.licenses      = ['Apache-2.0']
    s.summary       = 'DELETEME: only for checking that builds work'
    s.description   = 'Testing that builds work AND pre-warming gem caches'
    s.homepage      = 'https://github.com/cameronkerrnz/logstash-plugin-dev'
    s.authors       = ['Cameron Kerr']
    s.email         = 'cameron.kerr.nz@gmail.com'
    s.require_paths = ['lib']
  
    # Files
    s.files = Dir['lib/**/*','spec/**/*','vendor/**/*','*.gemspec','*.md','CONTRIBUTORS','Gemfile','LICENSE','NOTICE.TXT']
     # Tests
    s.test_files = s.files.grep(%r{^(test|spec|features)/})
  
    # Special flag to let us know this is actually a logstash plugin
    s.metadata = { "logstash_plugin" => "true", "logstash_group" => "filter" }
  
    # Gem dependencies
    s.add_runtime_dependency "logstash-core-plugin-api", "~> 2.0"
    s.add_development_dependency 'logstash-devutils'
  end
  