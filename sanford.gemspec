# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sanford/version'

Gem::Specification.new do |gem|
  gem.name          = "sanford"
  gem.version       = Sanford::VERSION
  gem.authors       = ["Collin Redding", "Kelly Redding"]
  gem.email         = ["collin.redding@me.com", "kelly@kellyredding.com"]
  gem.description   = "Simple hosts for Sanford services."
  gem.summary       = "Simple hosts for Sanford services."
  gem.homepage      = "https://github.com/redding/sanford"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency("daemons",           ["~>1.1"])
  gem.add_dependency("dat-tcp",           ["~>0.1"])
  gem.add_dependency("ns-options",        ["~>1.0.0.rc1"])
  gem.add_dependency("sanford-protocol",  ["~>0.4"])

  gem.add_development_dependency("assert",        ["~>1.0"])
  gem.add_development_dependency("assert-mocha",  ["~>1.0"])
end
