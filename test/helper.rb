# this file is automatically required when you run `assert`
# put any test helpers here

# add the root dir to the load path
$LOAD_PATH.unshift(File.expand_path("../..", __FILE__))

require 'pry' # require pry for debugging (`binding.pry`)

ENV['SANFORD_PROTOCOL_DEBUG'] = 'yes'

require 'sanford'
ROOT = File.expand_path('../..', __FILE__)

MyTestEngine = Class.new(Sanford::TemplateEngine) do
  def render(path, service_handler, locals)
    [path.to_s, service_handler.class.to_s, locals]
  end
end
Sanford.configure do |config|
  config.services_file = File.join(ROOT, 'test/support/services')
  config.set_template_source File.join(ROOT, 'test/support') do |s|
    s.engine 'test', MyTestEngine
  end
end
Sanford.init

require 'test/support/fake_connection'
require 'test/support/service_handlers'
require 'test/support/simple_client'
require 'test/support/helpers'
