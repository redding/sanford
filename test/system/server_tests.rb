require 'assert'
require 'sanford/server'

require 'sanford-protocol/fake_socket'
require 'test/support/app_server'

module Sanford::Server

  class SystemTests < Assert::Context
    desc "Sanford::Server"
    setup do
      # Turn off sanford-protocol debugging, this is turned on in
      # `test/helper.rb`. We don't want to debug the protocol, we want it to
      # behave how it will in a production setting. If protocol debugging is
      # turned on, then it won't wrap exceptions that occur within the protocol
      # and we will get unexpected results.
      @current_sanford_protocol_debug = ENV['SANFORD_PROTOCOL_DEBUG']
      ENV.delete('SANFORD_PROTOCOL_DEBUG')

      # Turn off sanford debugging. For the same reasons as above, we want
      # Sanford behave how it will in a production setting. If debugging is
      # turned on, the server will raise exceptions and we may get unexpected
      # results
      @current_sanford_debug = ENV['SANFORD_DEBUG']
      ENV.delete('SANFORD_DEBUG')
    end
    teardown do
      ENV['SANFORD_DEBUG'] = @current_sanford_debug
      ENV['SANFORD_PROTOCOL_DEBUG'] = @current_sanford_protocol_debug
    end

  end

  class RunningAppServerTests < SystemTests
    setup do
      @server = AppServer.new
      @client = TestClient.new(AppServer.ip, AppServer.port)
      @server_runner = ServerRunner.new(@server).tap(&:start)
    end
    teardown do
      @server_runner.stop
    end
    subject{ @response }

  end

  class SuccessTests < RunningAppServerTests
    desc "calling a service"
    setup do
      @message = Factory.string
      @client.set_request('echo', :message => @message)
      @response = @client.call
    end

    should "return a success response" do
      assert_equal 200, subject.code
      assert_nil subject.status.message
      assert_equal @message, subject.data
    end

  end

  class BadProtocolVersionTests < RunningAppServerTests
    desc "calling a server with an invalid protocol version"
    setup do
      @client.bytes = "\000"
      @response = @client.call
    end

    should "return a client error response" do
      assert_equal 400, subject.code
      assert_equal "Protocol version mismatch", subject.status.message
      assert_nil subject.data
    end

  end

  class BadMessageTests < RunningAppServerTests
    desc "calling a server with an invalid message size"
    setup do
      @client.bytes = [ Sanford::Protocol.msg_version, "\000" ].join
      @response = @client.call
    end

    should "return a client error response" do
      assert_equal 400, subject.code
      assert_equal "Empty message size", subject.status.message
      assert_nil subject.data
    end

  end

  class BadBodyTests < RunningAppServerTests
    desc "calling a server with an invalid message body"
    setup do
      # these are a special set of bytes that cause BSON to throw an exception
      @client.set_encoded_msg_body("\000\001\010\011" * 2)
      @response = @client.call
    end

    should "return a client error response" do
      assert_equal 400, subject.code
      assert_equal "Error reading message body.", subject.status.message
      assert_nil subject.data
    end

  end

  class NotFoundTests < RunningAppServerTests
    desc "with a request for a service the server doesn't provide"
    setup do
      @client.set_request('doesnt_exist')
      @response = @client.call
    end

    should "return a not found error response" do
      assert_equal 404, subject.code
      assert_nil subject.status.message
      assert_nil subject.data
    end

  end

  class ServerErrorTests < RunningAppServerTests
    desc "with a request that causes a server error"
    setup do
      @client.set_request('raise')
      @response = @client.call
    end

    should "return a server error response" do
      assert_equal 500, subject.code
      assert_equal "An unexpected error occurred.", subject.status.message
      assert_nil subject.data
    end

  end

  class BadRequestTests < RunningAppServerTests
    desc "calling a server with an invalid request"
    setup do
      @client.set_msg_body({})
      @response = @client.call
    end

    should "return a client error response" do
      assert_equal 400, subject.code
      assert_equal "The request doesn't contain a name.", subject.status.message
      assert_nil subject.data
    end

  end

  class BadResponseTests < RunningAppServerTests
    desc "calling a service that builds an invalid response"
    setup do
      @client.set_request('bad_response')
      @response = @client.call
    end

    should "return a server error response" do
      assert_equal 500, subject.code
      assert_equal "An unexpected error occurred.", subject.status.message
      assert_nil subject.data
    end

  end

  class TemplateTests < RunningAppServerTests
    desc "calling a service that renders a template"
    setup do
      @message = Factory.text
      @client.set_request('template', :message => @message)
      @response = @client.call
    end

    should "return a success response with the rendered data" do
      assert_equal 200, subject.code
      assert_nil subject.status.message
      assert_equal "ERB Template Message: #{@message}\n", subject.data
    end

  end

  class KeepAliveTests < RunningAppServerTests
    desc "receiving a keep-alive connection"
    setup do
      # no bytes means our client won't write any, this mimics a keep-alive
      # connection that connects and immediately disconnects
      @client.bytes = nil
      @response = @client.call_keep_alive
    end

    should "not write a response" do
      assert_equal "", subject
    end

  end

  class TimeoutErrorTests < RunningAppServerTests
    desc "with a client that connects but doesn't send anything"
    setup do
      @current_sanford_timeout = ENV['SANFORD_TIMEOUT']
      ENV['SANFORD_TIMEOUT'] = '0.1'

      # keep-alive messes up testing this, so we disable it for this test
      Assert.stub(@server.server_data, :receives_keep_alive){ false }

      @client.delay = 0.5
      @client.set_request('echo', :message => Factory.string)
      @response = @client.call
    end
    teardown do
      ENV['SANFORD_TIMEOUT'] = @current_sanford_timeout
    end

    should "return a timeout error response" do
      assert_equal 408, subject.code
      assert_nil subject.status.message
      assert_nil subject.data
    end

  end

  class HaltTests < RunningAppServerTests

    should "allow halting in a before callback" do
      @client.set_request('halt', :when => 'before')
      @response = @client.call

      assert_equal 200, subject.code
      assert_equal 'in before', subject.status.message
      assert_nil subject.data
    end

    should "allow halting in a before init callback" do
      @client.set_request('halt', :when => 'before_init')
      @response = @client.call

      assert_equal 200, subject.code
      assert_equal 'in before init', subject.status.message
      assert_nil subject.data
    end

    should "allow halting in init" do
      @client.set_request('halt', :when => 'init')
      @response = @client.call

      assert_equal 200, subject.code
      assert_equal 'in init', subject.status.message
      assert_nil subject.data
    end

    should "allow halting in an after init callback" do
      @client.set_request('halt', :when => 'after_init')
      @response = @client.call

      assert_equal 200, subject.code
      assert_equal 'in after init', subject.status.message
      assert_nil subject.data
    end

    should "allow halting in a before run callback" do
      @client.set_request('halt', :when => 'before_run')
      @response = @client.call

      assert_equal 200, subject.code
      assert_equal 'in before run', subject.status.message
      assert_nil subject.data
    end

    should "allow halting in run" do
      @client.set_request('halt', :when => 'run')
      @response = @client.call

      assert_equal 200, subject.code
      assert_equal 'in run', subject.status.message
      assert_nil subject.data
    end

    should "allow halting in an after run callback" do
      @client.set_request('halt', :when => 'after_run')
      @response = @client.call

      assert_equal 200, subject.code
      assert_equal 'in after run', subject.status.message
      assert_false subject.data
    end

    should "allow halting in an after callback" do
      @client.set_request('halt', :when => 'after')
      @response = @client.call

      assert_equal 200, subject.code
      assert_equal 'in after', subject.status.message
      assert_false subject.data
    end

  end

  class ErrorHandlerResponseTests < RunningAppServerTests
    desc "calling a service that triggers an error handler"
    setup do
      @client.set_request('custom_error')
      @response = @client.call
    end

    should "return a response generated by the error handler" do
      assert_equal 200, subject.code
      assert_nil subject.status.message
      expected = "The server on #{AppServer.ip}:#{AppServer.port} " \
                 "threw a StandardError."
      assert_equal expected, subject.data
    end

  end

  class WithEnvIpAndPortTests < SystemTests
    desc "with an env var ip and port"
    setup do
      # get our current ip address, need something different than 0.0.0.0 and
      # 127.0.0.1 to bind to
      ENV['SANFORD_IP']   = IPSocket.getaddress(Socket.gethostname)
      ENV['SANFORD_PORT'] = (AppServer.port + 1).to_s

      @server = AppServer.new
      @client = TestClient.new(ENV['SANFORD_IP'], ENV['SANFORD_PORT'])
      @server_runner = ServerRunner.new(@server).tap(&:start)
    end
    teardown do
      @server_runner.stop
      ENV.delete('SANFORD_IP')
      ENV.delete('SANFORD_PORT')
    end

    should "run the server on the env var ip and port" do
      @client.set_request('echo', :message => Factory.string)
      response = nil
      assert_nothing_raised{ response = @client.call }
      assert_equal 200, response.code
    end

  end

  class TestClient
    attr_accessor :delay, :bytes

    def initialize(ip, port)
      @ip = ip
      @port = port
      @delay = nil
      @bytes = nil
    end

    def set_request(name, params = nil)
      params ||= {}
      fake_socket = Sanford::Protocol::FakeSocket.with_request(name, params)
      @bytes = fake_socket.in
    end

    def set_msg_body(hash)
      fake_socket = Sanford::Protocol::FakeSocket.with_msg_body(hash)
      @bytes = fake_socket.in
    end

    def set_encoded_msg_body(bytes)
      fake_socket = Sanford::Protocol::FakeSocket.with_encoded_msg_body(bytes)
      @bytes = fake_socket.in
    end

    def call
      socket = TCPSocket.new(@ip, @port)
      socket.setsockopt(::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY, true)
      connection = Sanford::Protocol::Connection.new(socket)
      sleep(@delay) if @delay
      socket.send(@bytes, 0)
      socket.close_write
      Sanford::Protocol::Response.parse(connection.read)
    ensure
      socket.close rescue false
    end

    def call_keep_alive
      socket = TCPSocket.new(@ip, @port)
      socket.read
    ensure
      socket.close rescue false
    end
  end

  class ServerRunner
    def initialize(server)
      @server = server
      @thread = nil
    end

    def start
      @server.listen
      @thread = @server.start
    end

    def wakeup
      @thread.wakeup
    end

    def stop
      @server.halt
      @thread.join if @thread
    end
  end

end
