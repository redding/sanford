require 'logger'

class TestHost
  include Sanford::Host

  ip      'localhost'
  port    12000
  pid_dir File.expand_path('../../../tmp/', __FILE__)

  logger(Logger.new(File.expand_path("../../../log/test.log", __FILE__)).tap do |logger|
    logger.level = Logger::DEBUG
  end)
  verbose_logging true

  version 'v1' do
    service_handler_ns 'TestHost'

    service 'echo',       'Echo'
    service 'bad',        'Bad'
    service 'multiply',   'Multiply'
    service 'halt_it',    '::TestHost::HaltIt'
    service 'authorized', 'Authorized'
  end

  class Echo
    include Sanford::ServiceHandler

    def run!
      params['message']
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

class MyHost
  include Sanford::Host

  name  'my_host'
  ip    'my.local'
end

class InvalidHost
  include Sanford::Host

  name 'invalid_host'
end

class UndefinedHandlersHost
  include Sanford::Host

  version 'v1' do
    service 'undefined', 'ThisIsNotDefined'
  end
end

class EmptyHost
  include Sanford::Host
end
