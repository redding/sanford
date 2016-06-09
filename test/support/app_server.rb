require 'pathname'
require 'sanford-protocol'
require 'sanford'

if !defined?(ROOT_PATH)
  ROOT_PATH = Pathname.new(File.expand_path('../../..', __FILE__))
end

LOGGER = Logger.new(ROOT_PATH.join('log/app_server.log').to_s)
LOGGER.datetime_format = "" # turn off the datetime in the logs

class AppERBEngine < Sanford::TemplateEngine
  RenderScope = Class.new(Struct.new(:view)) do
    def get_binding; binding; end
  end

  def render(path, service_handler, locals)
    require 'erb'
    full_path = ROOT_PATH.join("test/support/#{path}.erb")

    b = RenderScope.new(service_handler).get_binding
    ERB.new(File.read(full_path)).result(b)
  end
end

class AppServer
  include Sanford::Server

  name 'app'
  ip   '127.0.0.1'
  port 12000

  receives_keep_alive true

  logger LOGGER
  verbose_logging true

  router do
    service_handler_ns 'AppHandlers'

    service 'echo',         'Echo'
    service 'raise',        'Raise'
    service 'bad_response', 'BadResponse'
    service 'template',     'Template'
    service 'halt',         'Halt'
    service 'custom_error', 'CustomError'
  end

  Sanford::TemplateSource.new(ROOT_PATH.join('test/support').to_s).tap do |s|
    s.engine 'erb', AppERBEngine
    template_source s
  end

  error do |exception, context|
    if context.request && context.request.name == 'custom_error'
      data = "The server on " \
             "#{context.server_data.ip}:#{context.server_data.port} " \
             "threw a #{exception.class}."
      Sanford::Protocol::Response.new(200, data)
    end
  end

end

module AppHandlers

  class Echo
    include Sanford::ServiceHandler

    def run!
      data(params['message'])
    end
  end

  class Raise
    include Sanford::ServiceHandler

    def run!
      raise "hahaha"
    end
  end

  class BadResponse
    include Sanford::ServiceHandler

    def run!
      data(Class.new)
    end
  end

  class Template
    include Sanford::ServiceHandler

    attr_reader :message

    def init!
      @message = params['message']
    end

    def run!
      render "template"
    end
  end

  class Halt
    include Sanford::ServiceHandler

    before do
      halt(200, :message => "in before") if params['when'] == 'before'
    end

    before_init do
      halt(200, :message => "in before init") if params['when'] == 'before_init'
    end

    def init!
      halt(200, :message => "in init") if params['when'] == 'init'
    end

    after_init do
      halt(200, :message => "in after init") if params['when'] == 'after_init'
    end

    before_run do
      halt(200, :message => "in before run") if params['when'] == 'before_run'
    end

    def run!
      halt(200, :message => "in run") if params['when'] == 'run'
      data(false)
    end

    after_run do
      halt(200, :message => "in after run") if params['when'] == 'after_run'
    end

    after do
      halt(200, :message => "in after") if params['when'] == 'after'
    end
  end

  class CustomError
    include Sanford::ServiceHandler

    def run!
      raise StandardError
    end
  end

end
