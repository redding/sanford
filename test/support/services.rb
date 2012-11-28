require 'logger'

class DummyHost
  include Sanford::Host

  ip      'localhost'
  port    12000
  pid_dir File.expand_path('../../../tmp/', __FILE__)

  logger = Logger.new(File.expand_path("../../../log/test.log", __FILE__))
  logger.level = Logger::DEBUG

  version 'v1' do
    service_handler_ns 'DummyHost'

    service 'echo',       'Echo'
    service 'bad',        'Bad'
    service 'multiply',   'Multiply'
    service 'halt_it',    '::DummyHost::HaltIt'
    service 'authorized', 'Authorized'
  end

  class Echo
    include Sanford::ServiceHandler

    def run!
      params
    end

  end

  class Bad
    include Sanford::ServiceHandler

    def run!
      raise "hahaha"
    end
  end

  class Multiply
    include Sanford::ServiceHandler

    def init!
      @number = params['number'] || 1
    end

    def run!
      @number * 2
    end
  end

  class HaltIt
    include Sanford::ServiceHandler

    def run!
      halt 728, {
        :message  => "I do what I want",
        :data     => [ 1, true, 'yes' ]
      }
    end
  end

  class Authorized
    include Sanford::ServiceHandler

    def before_run
      halt 401, :message => "Not authorized"
    end

  end

end
