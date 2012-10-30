# This test is intended as a high level test against Sanford's server. This will
# use multiple request scenarios to test out Sanford's behavior and how it
# responds.
#
require 'assert'

require 'sanford/test/helpers'

class RequestHandlingTest < Assert::Context
  include Sanford::Test::Helpers

  desc "Sanford's handling of requests"
  setup do
    @service_host = DummyHost.new
    @server = Sanford::Server.new(@service_host)
    @fake_socket = FakeSocket.new
  end

  # Simple service test that echos back the params sent to it
  class EchoTest < RequestHandlingTest
    desc "when hitting an echo service"
    setup do
      @fake_socket.request('echo', 'v1', "test")
      @server.serve(@fake_socket)
    end

    should "return a successful response and echo the params sent to it" do
      bytes = @fake_socket.write_stream.first
      response, size, serialized_version = parse_response(bytes)

      assert_equal Sanford::Response.serialized_protocol_version, serialized_version
      assert_equal 200, response.status.code
      assert_equal nil, response.status.message
      assert_equal 'test', response.result
    end
  end

  # Sending the server a completely wrong stream of bytes
  class BadMessageTest < RequestHandlingTest
    desc "when sent a invalid request stream"
    setup do
      @fake_socket.read_stream << "H"
      @server.serve(@fake_socket)
    end

    should "return a bad request response with an error message" do
      bytes = @fake_socket.write_stream.first
      response, size, serialized_version = parse_response(bytes)

      assert_equal Sanford::Response.serialized_protocol_version, serialized_version
      assert_equal 400, response.status.code
      assert_equal "The size couldn't be parsed.", response.status.message
      assert_equal nil, response.result
    end
  end

  # Sending the server a protocol version that doesn't match it's version
  class WrongProtocolVersionTest < RequestHandlingTest
    desc "when sent a request with a wrong protocol version"
    setup do
      @fake_socket.request('echo', 'v1', "test", { :protocol_version => 145 })
      @server.serve(@fake_socket)
    end

    should "return a bad request response with an error message" do
      bytes = @fake_socket.write_stream.first
      response, size, serialized_version = parse_response(bytes)

      assert_equal Sanford::Response.serialized_protocol_version, serialized_version
      assert_equal 400, response.status.code
      assert_equal "The protocol version didn't match the servers.", response.status.message
      assert_equal nil, response.result
    end
  end

  # Sending the server a body that it can't parse
  class BadBodyTest < RequestHandlingTest
    desc "when sent a request with an invalid body"
    setup do
      @fake_socket.request({ :serialized_body => 'Hello World!' })
      @server.serve(@fake_socket)
    end

    should "return a bad request response with an error message" do
      bytes = @fake_socket.write_stream.first
      response, size, serialized_version = parse_response(bytes)

      assert_equal Sanford::Response.serialized_protocol_version, serialized_version
      assert_equal 400, response.status.code
      assert_equal "The request body couldn't be parsed.", response.status.message
      assert_equal nil, response.result
    end
  end

  class MissingServiceNameTest < RequestHandlingTest
    desc "when sent a request with no service name"
    setup do
      @fake_socket.request(nil, 'v1', {})
      @server.serve(@fake_socket)
    end

    should "return a bad request response" do
      bytes = @fake_socket.write_stream.first
      response, size, serialized_version = parse_response(bytes)

      assert_equal Sanford::Response.serialized_protocol_version, serialized_version
      assert_equal 400, response.status.code
      assert_equal "The request doesn't contain a service name.", response.status.message
      assert_equal nil, response.result
    end
  end

  class MissingServiceVersionTest < RequestHandlingTest
    desc "when sent a request with no service version"
    setup do
      @fake_socket.request('what', nil, {})
      @server.serve(@fake_socket)
    end

    should "return a bad request response" do
      bytes = @fake_socket.write_stream.first
      response, size, serialized_version = parse_response(bytes)

      assert_equal Sanford::Response.serialized_protocol_version, serialized_version
      assert_equal 400, response.status.code
      assert_equal "The request doesn't contain a service version.", response.status.message
      assert_equal nil, response.result
    end
  end

  # Requesting a service that is not defined
  class NotFoundServiceTest < RequestHandlingTest
    desc "when sent a request with no matching service name"
    setup do
      @fake_socket.request('what', 'v1', {})
      @server.serve(@fake_socket)
    end

    should "return a bad request response" do
      bytes = @fake_socket.write_stream.first
      response, size, serialized_version = parse_response(bytes)

      assert_equal Sanford::Response.serialized_protocol_version, serialized_version
      assert_equal 404, response.status.code
      assert_equal nil, response.status.message
      assert_equal nil, response.result
    end
  end

  # Hitting a service that throws an exception
  class ErrorServiceTest < RequestHandlingTest
    desc "when sent a request that errors on the server"
    setup do
      @fake_socket.request('bad', 'v1', {})
      @server.serve(@fake_socket)
    end

    should "return a bad request response" do
      bytes = @fake_socket.write_stream.first
      response, size, serialized_version = parse_response(bytes)

      assert_equal Sanford::Response.serialized_protocol_version, serialized_version
      assert_equal 500, response.status.code
      assert_equal "An unexpected error occurred.", response.status.message
      assert_equal nil, response.result
    end
  end

  class ManualSuccessTest < RequestHandlingTest

  end

  class ManualErrorTest < RequestHandlingTest

  end

end
