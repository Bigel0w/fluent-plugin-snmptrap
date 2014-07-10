# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |gem|
  gem.name          = "fluent-plugin-snmptrap"
  gem.version       = "0.0.1"
  gem.date          = '2014-07-09'
  gem.authors       = ["Alex Pena"]
  gem.email         = ["pena.alex@gmail.com"]
  gem.summary       = %q{Fluentd input plugin for SNMP Traps}
  gem.description   = %q{FLuentd plugin for SNMP Traps... WIP}
  gem.homepage      = 'https://github.com/Bigel0w/fluent-plugin-snmptrap'
  gem.license       = 'MIT'

  gem.files         = `git ls-files`.split($\)                                    
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency "rake", '~> 0.9', '>= 0.9.6'

  gem.add_runtime_dependency "fluentd", '~> 0.10', '>= 0.10.51'
  gem.add_runtime_dependency "snmp", '~> 1.1', '>= 1.1.1'
end
