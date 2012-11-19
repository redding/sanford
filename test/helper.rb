ENV['SANFORD_PROTOCOL_DEBUG'] = 'yes'

require 'ostruct'

ROOT = File.expand_path('../..', __FILE__)

require 'sanford'

Sanford.configure do |config|
  config.services_config = File.join(ROOT, 'test/support/services')
end
Sanford.init

require 'test/support/service_handlers'
require 'test/support/simple_client'
require 'test/support/helpers'

if defined?(Assert)
  require 'assert-mocha'
end
