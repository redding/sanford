# This test is intended as a high level test against Sanford's server. This will
# use multiple request scenarios to test out Sanford's behavior and how it
# responds.
#
require 'assert'

require 'sanford-protocol/test/helpers'

class RequestHandlingTest < Assert::Context
  include Sanford::Protocol::Test::Helpers

  desc "Sanford's handling of requests"
  setup do
    @service_host = DummyHost.new
    @server = Sanford::Server.new(@service_host)
  end

  # Simple service test that echos back the params sent to it
  class EchoTest < RequestHandlingTest
    desc "when hitting an echo service"
    setup do
      @socket = self.fake_socket_with_request('v1', 'echo', 'test')
      @server.serve(@socket)
    end

    should "return a successful response and echo the params sent to it" do
      response = self.read_written_response_from_fake_socket(@socket)

      assert_equal 200,     response.status.code
      assert_equal nil,     response.status.message
      assert_equal 'test',  response.data
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
    setup do
      @socket = self.fake_socket_with(Sanford::Protocol.msg_version, "\000")
      @server.serve(@socket)
    end

    should "return a bad request response with an error message" do
      response = self.read_written_response_from_fake_socket(@socket)

      assert_equal 400,     response.status.code
      assert_match "size",  response.status.message
      assert_equal nil,     response.data
    end
  end

  # Sending the server a protocol version that doesn't match it's version
  class WrongProtocolVersionTest < ErroringRequestTest
    desc "when sent a request with a wrong protocol version"
    setup do
      @socket = self.fake_socket_with_msg_body({}, nil, "\000")
      @server.serve(@socket)
    end

    should "return a bad request response with an error message" do
      response = self.read_written_response_from_fake_socket(@socket)

      assert_equal 400,                 response.status.code
      assert_match "Protocol version",  response.status.message
      assert_equal nil,                 response.data
    end
  end

  # Sending the server a body that it can't parse
  class BadBodyTest < ErroringRequestTest
    desc "when sent a request with an invalid body"
    setup do
      @socket = self.fake_socket_with_encoded_msg_body("\000\001\010\011" * 2)
      @server.serve(@socket)
    end

    should "return a bad request response with an error message" do
      response = self.read_written_response_from_fake_socket(@socket)

      assert_equal 400,     response.status.code
      assert_match "body",  response.status.message
      assert_equal nil,     response.data
    end
  end

  class MissingServiceNameTest < ErroringRequestTest
    desc "when sent a request with no service name"
    setup do
      @socket = self.fake_socket_with_request('v1', nil, {})
      @server.serve(@socket)
    end

    should "return a bad request response" do
      response = self.read_written_response_from_fake_socket(@socket)

      assert_equal 400,       response.status.code
      assert_match "request", response.status.message
      assert_match "name",    response.status.message
      assert_equal nil,       response.data
    end
  end

  class MissingServiceVersionTest < ErroringRequestTest
    desc "when sent a request with no service version"
    setup do
      @socket = self.fake_socket_with_request(nil, 'what', {})
      @server.serve(@socket)
    end

    should "return a bad request response" do
      response = self.read_written_response_from_fake_socket(@socket)

      assert_equal 400,       response.status.code
      assert_match "request", response.status.message
      assert_match "version", response.status.message
      assert_equal nil,       response.data
    end
  end

  # Requesting a service that is not defined
  class NotFoundServiceTest < ErroringRequestTest
    desc "when sent a request with no matching service name"
    setup do
      @socket = self.fake_socket_with_request('v1', 'what', {})
      @server.serve(@socket)
    end

    should "return a bad request response" do
      response = self.read_written_response_from_fake_socket(@socket)

      assert_equal 404, response.status.code
      assert_equal nil, response.status.message
      assert_equal nil, response.data
    end
  end

  # Hitting a service that throws an exception
  class ErrorServiceTest < ErroringRequestTest
    desc "when sent a request that errors on the server"
    setup do
      @socket = self.fake_socket_with_request('v1', 'bad', {})
      @server.serve(@socket)
    end

    should "return a bad request response" do
      response = self.read_written_response_from_fake_socket(@socket)

      assert_equal 500,     response.status.code
      assert_match "error", response.status.message
      assert_equal nil,     response.data
    end
  end

  class HaltTest < RequestHandlingTest
    desc "when sent a request that halts"
    setup do
      @socket = self.fake_socket_with_request('v1', 'halt_it', {})
      @server.serve(@socket)
    end

    should "return the response that was halted" do
      response = self.read_written_response_from_fake_socket(@socket)

      assert_equal 728,                 response.status.code
      assert_equal "I do what I want",  response.status.message
      assert_equal [ 1, true, 'yes' ],  response.data
    end
  end

  class AuthorizeRequestTest < RequestHandlingTest
    desc "when sent a request that halts in a callback"
    setup do
      @socket = self.fake_socket_with_request('v1', 'authorized', {})
      @server.serve(@socket)
    end

    should "return the response that was halted" do
      response = self.read_written_response_from_fake_socket(@socket)

      assert_equal 401,               response.status.code
      assert_equal "Not authorized",  response.status.message
      assert_equal nil,               response.data
    end
  end

end
