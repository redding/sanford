require 'assert'

require 'sanford-protocol/test/helpers'

class Sanford::Connection

  class BaseTest < Assert::Context
    include Sanford::Protocol::Test::Helpers

    desc "Sanford::Connection"
    setup do
      @fake_socket = self.fake_socket_with_request('v1', 'echo', 'test')
      @connection = Sanford::Connection.new(DummyHost.new, @fake_socket)
    end
    subject{ @connection }

    should have_instance_methods :service_host, :exception_handler, :logger, :process
  end

  # The system test `test/system/request_handling_test.rb`, covers all the
  # special requests that can occur when given all sorts of invalid requests.

end
