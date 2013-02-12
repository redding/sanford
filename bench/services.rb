class BenchHost
  include Sanford::Host

  port     59284
  pid_dir  File.expand_path("../../tmp", __FILE__)

  logger           Logger.new(STDOUT)
  verbose_logging  false

  version 'v1' do
    service 'simple', 'BenchHost::Simple'
  end

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
