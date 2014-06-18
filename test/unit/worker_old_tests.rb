require 'assert'
require 'sanford/worker_old'

require 'sanford/host_data'
require 'test/support/fake_connection'

class Sanford::WorkerOld

  class UnitTests < Assert::Context
    desc "Sanford::WorkerOld"
    setup do
      @host_data = Sanford::HostData.new(TestHost)
      @connection = FakeConnection.with_request('service', {})
      @worker = Sanford::WorkerOld.new(@host_data, @connection)
    end
    subject{ @worker }

    should have_imeths :logger, :run

  end

  # `WorkerOld`'s logic is tested in the system test: `request_handling_test.rb`

end
