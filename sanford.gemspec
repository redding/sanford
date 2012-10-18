# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sanford/version'

Gem::Specification.new do |gem|
  gem.name          = "sanford"
  gem.version       = Sanford::VERSION
  gem.authors       = ["Collin Redding"]
  gem.email         = ["collin.redding@me.com"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency("bson",        ["~>1.7"])
  gem.add_dependency("daemons",     ["~>1.1"])
  gem.add_dependency("ns-options",  ["~>0.4"])

  gem.add_development_dependency("assert",        ["~> 0.8"])
  gem.add_development_dependency("assert-mocha",  ["~> 0.1"])
end
