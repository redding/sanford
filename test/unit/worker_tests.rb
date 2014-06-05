require 'assert'
require 'sanford/worker'

require 'sanford/host_data'
require 'test/support/fake_connection'

class Sanford::Worker

  class UnitTests < Assert::Context
    desc "Sanford::Worker"
    setup do
      @host_data = Sanford::HostData.new(TestHost)
      @connection = FakeConnection.with_request('service', {})
      @worker = Sanford::Worker.new(@host_data, @connection)
    end
    subject{ @worker }

    should have_imeths :logger, :run

  end

  # `Worker`'s logic is tested in the system test: `request_handling_test.rb`

end
