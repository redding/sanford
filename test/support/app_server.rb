require 'pathname'
require 'sanford'
require 'sanford-protocol'

if !defined?(ROOT_PATH)
  ROOT_PATH = Pathname.new(File.expand_path('../../..', __FILE__))
end

class AppServer
  include Sanford::Server

  name 'app'
  ip   'localhost'
  port 12000

  receives_keep_alive true

  logger Logger.new(ROOT_PATH.join('log/test_server.log').to_s)
  verbose_logging true

  router do
    service_handler_ns 'AppHandlers'

    service 'echo',         'Echo'
    service 'raise',        'Raise'
    service 'bad_response', 'BadResponse'
    service 'halt',         'Halt'
    service 'custom_error', 'CustomError'
  end

  error do |exception, config_data, request|
    if request && request.name == 'custom_error'
      data = "The server on #{config_data.ip}:#{config_data.port} " \
             "threw a #{exception.class}."
      Sanford::Protocol::Response.new(200, data)
    end
  end

end

module AppHandlers

  class Echo
    include Sanford::ServiceHandler

    def run!
      params['message']
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
      Class.new
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
      false
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