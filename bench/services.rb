class BenchHost
  include Sanford::Host

  configure do
    port    12000
    pid_dir File.expand_path("../../tmp", __FILE__)
  end

  version 'v1' do
    service 'simple', 'BenchHost::SimpleService'
  end

  class SimpleService
    include Sanford::ServiceHandler

    def run!
      { :string => 'test', :int => 1, :float => 2.1, :boolean => true,
        :hash => { :something => 'else' }, :array => [ 1, 2, 3 ],
        :request_number => self.request.params['request_number']
      }
    end

  end

end
