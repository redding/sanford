# This test is intended as a high level test against Sanford's server. This will
# use multiple request scenarios to test out Sanford's behavior and how it
# responds. These tests depend on a socket (or the protocol's connection) and
# thus are a system level test.
#
require 'assert'

require 'sanford/manager'
require 'sanford-protocol/test/fake_socket'

class RequestHandlingTest < Assert::Context
  desc "Sanford's handling of requests"


  # turn off the protocol's debugging (in case it's on) and turn on Sanford's
  # debugging
  class FakeConnectionTest < RequestHandlingTest
    setup do
      @env_sanford_protocol_debug = ENV['SANFORD_PROTOCOL_DEBUG']
      @env_sanford_debug = ENV['SANFORD_DEBUG']
      ENV.delete('SANFORD_PROTOCOL_DEBUG')
      ENV['SANFORD_DEBUG'] = '1'

      @host_data = Sanford::HostData.new(TestHost)
    end
    teardown do
      ENV['SANFORD_DEBUG'] = @env_sanford_debug
      ENV['SANFORD_PROTOCOL_DEBUG'] = @env_sanford_protocol_debug
    end
  end

  class EchoTest < FakeConnectionTest
    desc "running a request for the echo server"
    setup do
      @connection = FakeConnection.with_request('v1', 'echo', { :message => 'test' })
      @worker = Sanford::Worker.new(@host_data, @connection)
    end

    should "return a successful response and echo the params sent to it" do
      assert_nothing_raised{ @worker.run }
      response = @connection.response

      assert_equal 200,     response.code
      assert_equal nil,     response.status.message
      assert_equal 'test',  response.data
    end

  end

  class MissingServiceVersionTest < FakeConnectionTest
    desc "running a request with no service version"
    setup do
      request_hash = Sanford::Protocol::Request.new('v1', 'what', {}).to_hash
      request_hash.delete('version')
      @connection = FakeConnection.new(request_hash)
      @worker = Sanford::Worker.new(@host_data, @connection)
    end

    should "return a bad request response" do
      assert_raises(Sanford::Protocol::BadRequestError) do
        @worker.run
      end
      response = @connection.response

      assert_equal 400,       response.code
      assert_match "request", response.status.message
      assert_match "version", response.status.message
      assert_equal nil,       response.data
    end

  end

  class MissingServiceNameTest < FakeConnectionTest
    desc "running a request with no service name"
    setup do
      request_hash = Sanford::Protocol::Request.new('v1', 'what', {}).to_hash
      request_hash.delete('name')
      @connection = FakeConnection.new(request_hash)
      @worker = Sanford::Worker.new(@host_data, @connection)
    end

    should "return a bad request response" do
      assert_raises(Sanford::Protocol::BadRequestError) do
        @worker.run
      end
      response = @connection.response

      assert_equal 400,       response.code
      assert_match "request", response.status.message
      assert_match "name",    response.status.message
      assert_equal nil,       response.data
    end

  end

  class NotFoundServiceTest < FakeConnectionTest
    desc "running a request with no matching service name"
    setup do
      @connection = FakeConnection.with_request('v1', 'what', {})
      @worker = Sanford::Worker.new(@host_data, @connection)
    end

    should "return a bad request response" do
      assert_raises(Sanford::NotFoundError) do
        @worker.run
      end
      response = @connection.response

      assert_equal 404, response.code
      assert_equal nil, response.status.message
      assert_equal nil, response.data
    end

  end

  class ErrorServiceTest < FakeConnectionTest
    desc "running a request that errors on the server"
    setup do
      @connection = FakeConnection.with_request('v1', 'bad', {})
      @worker = Sanford::Worker.new(@host_data, @connection)
    end

    should "return a bad request response" do
      assert_raises(RuntimeError) do
        @worker.run
      end
      response = @connection.response

      assert_equal 500,     response.code
      assert_match "error", response.status.message
      assert_equal nil,     response.data
    end

  end

  class HaltTest < FakeConnectionTest
    desc "running a request that halts"
    setup do
      @connection = FakeConnection.with_request('v1', 'halt_it', {})
      @worker = Sanford::Worker.new(@host_data, @connection)
    end

    should "return the response that was halted" do
      assert_nothing_raised{ @worker.run }
      response = @connection.response

      assert_equal 728,                 response.code
      assert_equal "I do what I want",  response.status.message
      assert_equal [ 1, true, 'yes' ],  response.data
    end

  end

  class AuthorizeRequestTest < FakeConnectionTest
    desc "running a request that halts in a callback"
    setup do
      @connection = FakeConnection.with_request('v1', 'authorized', {})
      @worker = Sanford::Worker.new(@host_data, @connection)
    end

    should "return the response that was halted" do
      assert_nothing_raised{ @worker.run }
      response = @connection.response

      assert_equal 401,               response.code
      assert_equal "Not authorized",  response.status.message
      assert_equal nil,               response.data
    end

  end

  class WithCustomErrorHandlerTest < FakeConnectionTest
    desc "running a request that triggers our custom error handler"
    setup do
      @connection = FakeConnection.with_request('v1', 'custom_error', {})
      @worker = Sanford::Worker.new(@host_data, @connection)
    end

    should "return the response that was halted" do
      assert_raises(::MyCustomError){ @worker.run }
      response = @connection.response

      assert_equal 987,               response.code
      assert_equal "custom error!",   response.status.message
      assert_equal nil,               response.data
    end

  end

  class WithBadResponseHashTest < FakeConnectionTest
    desc "running a request that builds an object that can't be encoded"
    setup do
      @connection = FakeConnection.with_request('v1', 'echo', { :message => 'cant encode' }, true)
      @worker = Sanford::Worker.new(@host_data, @connection)
    end

    should "return the response that was halted" do
      assert_raises(RuntimeError){ @worker.run }
      response = @connection.response

      assert_equal 500,                             response.code
      assert_equal "An unexpected error occurred.", response.status.message
      assert_equal nil,                             response.data
    end

  end

  class ForkedServerTest < RequestHandlingTest
    include Test::ForkServerHelper

    setup do
      @server = Sanford::Server.new(TestHost, { :ready_timeout => 0 })
    end

  end

  # Simple service test that echos back the params sent to it
  class EchoServerTest < ForkedServerTest
    desc "when hitting an echo service"

    should "return a successful response and echo the params sent to it" do
      self.start_server(@server) do
        response = SimpleClient.call_with_request(TestHost, 'v1', 'echo', {
          :message => 'test'
        })

        assert_equal 200,     response.code
        assert_equal nil,     response.status.message
        assert_equal 'test',  response.data
      end
    end
  end

  class ErroringRequestTest < ForkedServerTest
    setup do
      @env_sanford_protocol_debug = ENV['SANFORD_PROTOCOL_DEBUG']
      ENV.delete('SANFORD_PROTOCOL_DEBUG')
    end
    teardown do
      ENV['SANFORD_PROTOCOL_DEBUG'] = @env_sanford_protocol_debug
    end
  end

  # Sending the server a completely wrong stream of bytes
  class BadMessageTest < ErroringRequestTest
    desc "when sent a invalid request stream"

    should "return a bad request response with an error message" do
      self.start_server(@server) do
        bytes = [ Sanford::Protocol.msg_version, "\000" ].join
        response = SimpleClient.call_with(TestHost, bytes)

        assert_equal 400,     response.code
        assert_match "size",  response.status.message
        assert_equal nil,     response.data
      end
    end
  end

  # Sending the server a protocol version that doesn't match it's version
  class WrongProtocolVersionTest < ErroringRequestTest
    desc "when sent a request with a wrong protocol version"

    should "return a bad request response with an error message" do
      self.start_server(@server) do
        bytes = [ Sanford::Protocol.msg_version, "\000" ].join
        response = SimpleClient.call_with_msg_body(TestHost, {}, nil, "\000")

        assert_equal 400,                 response.code
        assert_match "Protocol version",  response.status.message
        assert_equal nil,                 response.data
      end
    end
  end

  # Sending the server a body that it can't parse
  class BadBodyTest < ErroringRequestTest
    desc "when sent a request with an invalid body"
    should "return a bad request response with an error message" do
      self.start_server(@server) do
        response = SimpleClient.call_with_encoded_msg_body(TestHost, "\000\001\010\011" * 2)

        assert_equal 400,     response.code
        assert_match "body",  response.status.message
        assert_equal nil,     response.data
      end
    end
  end

  class HangingRequestTest < ErroringRequestTest
    desc "when a client connects but doesn't send anything for to long"
    setup do
      ENV['SANFORD_TIMEOUT'] = '0.1'
    end
    teardown do
      ENV.delete('SANFORD_TIMEOUT')
    end

    should "timeout" do
      self.start_server(@server) do
        client = SimpleClient.new(TestHost, :with_delay => 0.2)
        response = client.call_with_request('v1', 'echo', { :message => 'test' })

        assert_equal 408,   response.code
        assert_equal nil,   response.status.message
        assert_equal nil,   response.data
      end
    end
  end

  # essentially, don't call `IO.select`
  class FakeProtocolConnection < Sanford::Protocol::Connection
    def wait_for_data(*args)
      true
    end
  end

  class WithAKeepAliveTest < ForkedServerTest
    desc "receiving a keep-alive connection"
    setup do
      ENV['SANFORD_DEBUG'] = 'yes'
      @server = Sanford::Server.new(TestHost, {
        :ready_timeout        => 0,
        :receives_keep_alive  => true
      })
      @socket = Sanford::Protocol::Test::FakeSocket.new
      @fake_connection = FakeProtocolConnection.new(@socket)
      Sanford::Protocol::Connection.stubs(:new).with(@socket).returns(@fake_connection)
    end
    teardown do
      Sanford::Protocol::Connection.unstub(:new)
      ENV.delete('SANFORD_DEBUG')
    end

    should "not error and nothing should be written" do
      assert_nothing_raised do
        @server.serve(@socket)

        assert_equal "", @socket.out
      end
    end

  end

end
