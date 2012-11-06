require 'assert'

class Sanford::ConnectionHandler

  class BaseTest < Assert::Context
    desc "Sanford::Server::ConnectionHandler"
    setup do
      @fake_socket = FakeSocket.new
      @fake_socket.request('echo', 'v1', 'test')
      @connection_handler = Sanford::ConnectionHandler.new(DummyHost.new, @fake_socket)
    end
    subject{ @connection_handler }

    should have_instance_methods :client_socket, :service_host, :logger, :request, :response,
      :serialized_response

    should "set it's request attribute to an instance of Sanford::Request" do
      assert_instance_of Sanford::Request, subject.request
      assert_equal 'echo', subject.request.service_name
      assert_equal 'v1', subject.request.service_version
      assert_equal 'test', subject.request.params
    end

    should "set it's response attribute to an instance of Sanford::Response" do
      assert_instance_of Sanford::Response, subject.response
      assert_equal 200, subject.response.status.code
      assert_equal 'test', subject.response.result
      assert_equal subject.response.serialize, subject.serialized_response
    end

  end

  class RequestThatErrorsTest < BaseTest
    desc "given a request that errors"
    setup do
      @fake_socket = FakeSocket.new
      @fake_socket.request('bad', 'v1', 'test')
      @connection_handler = Sanford::ConnectionHandler.new(DummyHost.new, @fake_socket)
    end

    should "set it's response attribute to an instance of Sanford::Response" do
      assert_equal 500, subject.response.status.code
      assert_equal "An unexpected error occurred.", subject.response.status.message
      assert_equal nil, subject.response.result
    end

  end

  # The system test `test/system/request_handling_test.rb`, covers all the
  # special requests that can occur when given all sorts of invalid requests.

end
