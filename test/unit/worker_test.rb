require 'assert'
require 'sanford-protocol/test/helpers'

class Sanford::Worker

  class BaseTest < Assert::Context
    include Sanford::Protocol::Test::Helpers

    desc "Sanford::Worker"
    setup do
      @host_data = Sanford::HostData.new(TestHost)
      @connection = FakeConnection.with_request('version', 'service', {})
      @worker = Sanford::Worker.new(@host_data, @connection)
    end
    subject{ @worker }

    should have_instance_methods :logger, :run

  end

  # `Worker`'s logic is tested in the system test: `request_handling_test.rb`

end
