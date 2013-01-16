# This test is intended as a high level test against Sanford's server. This will
# use multiple request scenarios to test out Sanford's behavior and how it
# responds. These tests depend on a socket (or the protocol's connection) and
# thus are a system level test.
#
require 'assert'

class RequestHandlingTest < Assert::Context
  include Test::ForkServerHelper

  desc "Sanford's handling of requests"
  setup do
    @service_host = TestHost
    @server = Sanford::Server.new(@service_host, { :ready_timeout => 0 })
  end

  # Simple service test that echos back the params sent to it
  class EchoTest < RequestHandlingTest
    desc "when hitting an echo service"

    should "return a successful response and echo the params sent to it" do
      self.start_server(@server) do
        response = SimpleClient.call_with_request(@service_host, 'v1', 'echo', {
          :message => 'test'
        })

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

  class HangingRequestTest < ErroringRequestTest
    desc "when a client connects but doesn't send anything"
    setup do
      ENV['SANFORD_TIMEOUT'] = '0.1'
    end
    teardown do
      ENV.delete('SANFORD_TIMEOUT')
    end

    should "timeout" do
      self.start_server(@server) do
        client = SimpleClient.new(@service_host, :with_delay => 0.2)
        response = client.call_with_request('v1', 'echo', { :message => 'test' })

        assert_equal 408,   response.status.code
        assert_equal nil,   response.status.message
        assert_equal nil,   response.data
      end
    end
  end

end
