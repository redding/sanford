# this file is automatically required when you run `assert`
# put any test helpers here

# add the root dir to the load path
$LOAD_PATH.unshift(File.expand_path("../..", __FILE__))

require 'pry' # require pry for debugging (`binding.pry`)

ENV['SANFORD_PROTOCOL_DEBUG'] = 'yes'

require 'pathname'
ROOT_PATH = Pathname.new(File.expand_path('../..', __FILE__))

require 'sanford'
MyTestEngine = Class.new(Sanford::TemplateEngine) do
  def render(path, service_handler, locals)
    [path.to_s, service_handler.class.to_s, locals]
  end
end
Sanford.configure do |config|
  config.services_file = ROOT_PATH.join('test/support/services').to_s
  config.set_template_source ROOT_PATH.join('test/support').to_s do |s|
    s.engine 'test', MyTestEngine
  end
end
Sanford.init

require 'test/support/factory'
require 'test/support/fake_connection'
require 'test/support/service_handlers'
