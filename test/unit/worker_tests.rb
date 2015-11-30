require 'assert'
require 'sanford/worker'

require 'dat-tcp/worker'
require 'much-plugin'
require 'sanford-protocol/fake_connection'
require 'sanford/server_data'
require 'test/support/fake_server_connection'

module Sanford::Worker

  class UnitTests < Assert::Context
    include DatTCP::Worker::TestHelpers

    desc "Sanford::Worker"
    setup do
      @worker_class = Class.new{ include Sanford::Worker }
    end
    subject{ @worker_class }

    should "use much-plugin" do
      assert_includes MuchPlugin, Sanford::Worker
    end

    should "be a dat-tcp worker" do
      assert_includes DatTCP::Worker, subject
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @socket      = Factory.binary
      @server_data = Sanford::ServerData.new

      @connection = FakeServerConnection.new
      Assert.stub(Connection, :new).with(@socket){ @connection }

      @ch_spy = nil
      Assert.stub(Sanford::ConnectionHandler, :new) do |*args|
        @ch_spy = ConnectionHandlerSpy.new(*args)
      end

      @worker_params = {
        :sanford_server_data => @server_data
      }
      @runner = test_runner(@worker_class, :params => @worker_params)
    end
    subject{ @runner }

    should "build and run a connection handler when it processes a socket" do
      Assert.stub(@server_data, :receives_keep_alive){ false }
      @connection.read_data = Factory.string
      subject.work(@socket)

      assert_not_nil @ch_spy
      assert_equal @server_data, @ch_spy.server_data
      assert_equal @connection,  @ch_spy.connection
      assert_true @ch_spy.run_called
    end

    should "not run a connection handler when it processes a " \
           "keep-alive connection and its configured to expect them" do
      Assert.stub(@server_data, :receives_keep_alive){ true }
      @connection.read_data = nil # nothing to read makes it a keep-alive
      subject.work(@socket)

      assert_nil @ch_spy
    end

    should "run a connection handler when it processes a " \
           "keep-alive connection and its not configured to expect them" do
      Assert.stub(@server_data, :receives_keep_alive){ false }
      @connection.read_data = nil # nothing to read makes it a keep-alive
      subject.work(@socket)

      assert_not_nil @ch_spy
      assert_equal @server_data, @ch_spy.server_data
      assert_equal @connection,  @ch_spy.connection
      assert_true @ch_spy.run_called
    end

  end

  class ConnectionTests < UnitTests
    desc "Connection"
    setup do
      fake_socket = Factory.string
      @protocol_conn = Sanford::Protocol::FakeConnection.new(Factory.binary)
      Assert.stub(Sanford::Protocol::Connection, :new).with(fake_socket) do
        @protocol_conn
      end
      @connection = Connection.new(fake_socket)
    end
    subject{ @connection }

    should have_imeths :read_data, :write_data, :peek_data
    should have_imeths :close_write

    should "default its timeout" do
      assert_equal 1.0, subject.timeout
    end

    should "allowing reading from the protocol connection" do
      result = subject.read_data
      assert_equal @protocol_conn.read_data, result
      assert_equal @protocol_conn.read_timeout, subject.timeout
    end

    should "allowing writing to the protocol connection" do
      data = Factory.binary
      subject.write_data(data)
      assert_equal @protocol_conn.write_data, data
    end

    should "allowing peeking from the protocol connection" do
      result = subject.peek_data
      assert_equal @protocol_conn.peek_data, result
      assert_equal @protocol_conn.peek_timeout, subject.timeout
    end

    should "allow closing the write stream on the protocol connection" do
      assert_false @protocol_conn.closed_write
      subject.close_write
      assert_true @protocol_conn.closed_write
    end

  end

  class TCPCorkTests < UnitTests
    desc "TCPCork"
    subject{ TCPCork }

    should have_imeths :apply, :remove

  end

  class TestHelpersTests < UnitTests
    desc "TestHelpers"
    setup do
      @context_class = Class.new{ include TestHelpers }
      @context = @context_class.new
    end
    subject{ @context }

    should have_imeths :test_runner

    should "mixin dat-tcp's worker test helpers" do
      assert_includes DatTCP::Worker::TestHelpers, @context_class
    end

    should "super worker params needed to run a sanford worker" do
      runner = @context.test_runner(@worker_class)
      worker_params = runner.dwp_runner.worker_params

      assert_instance_of Sanford::ServerData, worker_params[:sanford_server_data]
    end

    should "allow providing custom worker params for running a sanford worker" do
      @params = {
        :sanford_server_data => Factory.string,
      }
      runner = @context.test_runner(@worker_class, :params => @params)

      assert_equal @params, runner.dwp_runner.worker_params
    end

  end

  class ConnectionHandlerSpy
    attr_reader :server_data, :connection, :run_called

    def initialize(server_data, connection)
      @server_data = server_data
      @connection  = connection
      @run_called  = false
    end

    def run
      @run_called = true
    end
  end

end
