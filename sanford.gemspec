# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sanford/version'

Gem::Specification.new do |gem|
  gem.name          = "sanford"
  gem.version       = Sanford::VERSION
  gem.authors       = ["Collin Redding", "Kelly Redding"]
  gem.email         = ["collin.redding@me.com", "kelly@kellyredding.com"]
  gem.summary       = "Sanford TCP protocol server for hosting services"
  gem.description   = "Sanford TCP protocol server for hosting services"
  gem.homepage      = "https://github.com/redding/sanford"
  gem.license       = 'MIT'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency("assert", ["~> 2.16.1"])

  gem.add_dependency("dat-tcp",          ["~> 0.8.1"])
  gem.add_dependency("much-plugin",      ["~> 0.2.0"])
  gem.add_dependency("sanford-protocol", ["~> 0.12.0"])
end
