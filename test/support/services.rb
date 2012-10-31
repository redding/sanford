require 'logger'

class DummyHost
  include Sanford::Host

  LOGGER = begin
    logger = Logger.new(File.expand_path("../../../log/test.log", __FILE__))
    logger.level = Logger::DEBUG
    logger
  end

  configure do
    host    'fake.local'
    port    8000
    pid_dir '/path/to/pids'
    logger  LOGGER
  end

  version 'v1' do
    service_handler_ns 'DummyHost'

    service 'echo',       'Echo'
    service 'bad',        'Bad'
    service 'multiply',   'Multiply'
    service 'halt_it',    '::DummyHost::HaltIt'
  end

  class Echo
    include Sanford::ServiceHandler

    def run!
      self.request.params
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
      @number = self.request.params['number'] || 1
    end

    def run!
      @number * 2
    end
  end

  class HaltIt

    include Sanford::ServiceHandler

    def run!
      halt 728, {
        :message => "I do what I want",
        :result => [ 1, true, 'yes' ]
      }
    end
  end

end
