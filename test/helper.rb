ROOT = File.expand_path('../..', __FILE__)

require 'sanford'

Sanford::Config.services_config = File.join(ROOT, 'test/support/services')
Sanford::Manager.load_configuration

if defined?(Assert)
  require 'assert-mocha'
end
