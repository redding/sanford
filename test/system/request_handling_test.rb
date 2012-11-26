# This test is intended as a high level test against Sanford's server. This will
# use multiple request scenarios to test out Sanford's behavior and how it
# responds.
#
require 'assert'

class RequestHandlingTest < Assert::Context
  include TestHelper

  desc "Sanford's handling of requests"
  setup do
    @service_host = DummyHost.new
    @server = Sanford::Server.new(@service_host, { :ready_timeout => 0 })
  end

  # Simple service test that echos back the params sent to it
  class EchoTest < RequestHandlingTest
    desc "when hitting an echo service"

    should "return a successful response and echo the params sent to it" do
      self.start_server(@server) do
        response = SimpleClient.call_with_request(@service_host, 'v1', 'echo', 'test')

        assert_equal 200,     response.status.code
        assert_equal nil,     response.status.message
        assert_equal 'test',  response.data
      end
    end
  end

  class ErroringRequestTest < RequestHandlingTest
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
        response = SimpleClient.call_with(@service_host, bytes)

        assert_equal 400,     response.status.code
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
        response = SimpleClient.call_with_msg_body(@service_host, {}, nil, "\000")

        assert_equal 400,                 response.status.code
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
        response = SimpleClient.call_with_encoded_msg_body(@service_host, "\000\001\010\011" * 2)

        assert_equal 400,     response.status.code
        assert_match "body",  response.status.message
        assert_equal nil,     response.data
      end
    end
  end

  class MissingServiceNameTest < ErroringRequestTest
    desc "when sent a request with no service name"

    should "return a bad request response" do
      self.start_server(@server) do
        response = SimpleClient.call_with_request(@service_host, 'v1', nil, {})

        assert_equal 400,       response.status.code
        assert_match "request", response.status.message
        assert_match "name",    response.status.message
        assert_equal nil,       response.data
      end
    end
  end

  class MissingServiceVersionTest < ErroringRequestTest
    desc "when sent a request with no service version"

    should "return a bad request response" do
      self.start_server(@server) do
        response = SimpleClient.call_with_request(@service_host, nil, 'what', {})

        assert_equal 400,       response.status.code
        assert_match "request", response.status.message
        assert_match "version", response.status.message
        assert_equal nil,       response.data
      end
    end
  end

  # Requesting a service that is not defined
  class NotFoundServiceTest < ErroringRequestTest
    desc "when sent a request with no matching service name"

    should "return a bad request response" do
      self.start_server(@server) do
        response = SimpleClient.call_with_request(@service_host, 'v1', 'what', {})

        assert_equal 404, response.status.code
        assert_equal nil, response.status.message
        assert_equal nil, response.data
      end
    end
  end

  # Hitting a service that throws an exception
  class ErrorServiceTest < ErroringRequestTest
    desc "when sent a request that errors on the server"

    should "return a bad request response" do
      self.start_server(@server) do
        response = SimpleClient.call_with_request(@service_host, 'v1', 'bad', {})

        assert_equal 500,     response.status.code
        assert_match "error", response.status.message
        assert_equal nil,     response.data
      end
    end
  end

  class HaltTest < RequestHandlingTest
    desc "when sent a request that halts"

    should "return the response that was halted" do
      self.start_server(@server) do
        response = SimpleClient.call_with_request(@service_host, 'v1', 'halt_it', {})

        assert_equal 728,                 response.status.code
        assert_equal "I do what I want",  response.status.message
        assert_equal [ 1, true, 'yes' ],  response.data
      end
    end
  end

  class AuthorizeRequestTest < RequestHandlingTest
    desc "when sent a request that halts in a callback"

    should "return the response that was halted" do
      self.start_server(@server) do
        response = SimpleClient.call_with_request(@service_host, 'v1', 'authorized', {})

        assert_equal 401,               response.status.code
        assert_equal "Not authorized",  response.status.message
        assert_equal nil,               response.data
      end
    end
  end

end
