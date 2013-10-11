class BenchHost
  include Sanford::Host

  port     59284
  pid_file File.expand_path("../../tmp/bench_host.pid", __FILE__)

  logger           Logger.new(STDOUT)
  verbose_logging  false

  service 'simple', 'BenchHost::Simple'

  class Simple
    include Sanford::ServiceHandler

    def run!
      { :string => 'test', :int => 1, :float => 2.1, :boolean => true,
        :hash => { :something => 'else' }, :array => [ 1, 2, 3 ],
        :request_number => self.request.params['request_number']
      }
    end

  end

end
