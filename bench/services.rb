class BenchHost
  include Sanford::Host

  configure do |config|
    config.port     = 12000
    config.pid_dir  = File.expand_path("../../tmp", __FILE__)
  end

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
