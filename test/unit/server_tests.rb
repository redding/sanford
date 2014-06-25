require 'assert'
require 'sanford/server'

require 'dat-tcp/server_spy'
require 'ns-options/assert_macros'
require 'sanford/route'
require 'sanford-protocol/fake_connection'
require 'test/support/fake_connection'

module Sanford::Server

  class UnitTests < Assert::Context
    desc "Sanford::Server"
    setup do
      @server_class = Class.new do
        include Sanford::Server
      end
    end
    subject{ @server_class }

    should have_imeths :configuration
    should have_imeths :name, :ip, :port, :pid_file
    should have_imeths :receives_keep_alive

    should "know its configuration" do
      config = subject.configuration
      assert_instance_of Configuration, config
      assert_same config, subject.configuration
    end

    should "allow reading/writing its configuration name" do
      new_name = Factory.string
      subject.name(new_name)
      assert_equal new_name, subject.configuration.name
      assert_equal new_name, subject.name
    end

    should "allow reading/writing its configuration ip" do
      new_ip = Factory.string
      subject.ip(new_ip)
      assert_equal new_ip, subject.configuration.ip
      assert_equal new_ip, subject.ip
    end

    should "allow reading/writing its configuration port" do
      new_port = Factory.integer
      subject.port(new_port)
      assert_equal new_port, subject.configuration.port
      assert_equal new_port, subject.port
    end

    should "allow reading/writing its configuration pid file" do
      new_pid_file = Factory.string
      subject.pid_file(new_pid_file)
      expected = Pathname.new(new_pid_file)
      assert_equal expected, subject.configuration.pid_file
      assert_equal expected, subject.pid_file
    end

    should "allow reading/writing its configuration receives keep alive" do
      new_keep_alive = Factory.boolean
      subject.receives_keep_alive(new_keep_alive)
      assert_equal new_keep_alive, subject.configuration.receives_keep_alive
      assert_equal new_keep_alive, subject.receives_keep_alive
    end

    should "allow reading/writing its configuration verbose logging" do
      new_verbose = Factory.boolean
      subject.verbose_logging(new_verbose)
      assert_equal new_verbose, subject.configuration.verbose_logging
      assert_equal new_verbose, subject.verbose_logging
    end

    should "allow reading/writing its configuration logger" do
      new_logger = Factory.string
      subject.logger(new_logger)
      assert_equal new_logger, subject.configuration.logger
      assert_equal new_logger, subject.logger
    end

    should "allow adding init procs to its configuration" do
      new_init_proc = proc{ Factory.string }
      subject.init(&new_init_proc)
      assert_includes new_init_proc, subject.configuration.init_procs
    end

    should "allow adding error procs to its configuration" do
      new_error_proc = proc{ Factory.string }
      subject.error(&new_error_proc)
      assert_includes new_error_proc, subject.configuration.error_procs
    end

    should "allow reading/writing its configuration router" do
      new_router = Factory.string
      subject.router(new_router)
      assert_equal new_router, subject.configuration.router
      assert_equal new_router, subject.router
    end

    should "allow configuring the router by passing a block to `router`" do
      new_router = Factory.string

      block_scope = nil
      subject.router(new_router){ block_scope = self }
      assert_equal new_router, subject.router
      assert_equal new_router, block_scope
    end

    should "allow setting the configuration template source" do
      new_path = Factory.string
      yielded = nil
      subject.set_template_source(new_path){ |s| yielded = s }
      assert_equal new_path, subject.configuration.template_source.path
      assert_equal subject.configuration.template_source, yielded
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @server_class.name Factory.string
      @server_class.ip Factory.string
      @server_class.port Factory.integer
      @server_class.error{ Factory.string }
      @server_class.router do
        service Factory.string, TestHandler.to_s
      end

      @dat_tcp_server_spy = DatTCP::ServerSpy.new
      Assert.stub(DatTCP::Server, :new) do |&block|
        @dat_tcp_server_spy.serve_proc = block
        @dat_tcp_server_spy
      end

      @server = @server_class.new
    end
    subject{ @server }

    should have_readers :server_data, :dat_tcp_server
    should have_imeths :name, :ip, :port
    should have_imeths :file_descriptor, :client_file_descriptors
    should have_imeths :listen, :start, :pause, :stop, :halt
    should have_imeths :paused?

    should "have validated its configuration" do
      assert_true subject.class.configuration.valid?
    end

    should "know its server data" do
      configuration = subject.class.configuration
      sd = subject.server_data

      assert_instance_of Sanford::ServerData, sd
      assert_equal configuration.name, sd.name
      assert_equal configuration.ip, sd.ip
      assert_equal configuration.port, sd.port
      assert_equal configuration.verbose_logging, sd.verbose_logging
      assert_equal configuration.receives_keep_alive, sd.receives_keep_alive
      assert_equal configuration.error_procs, sd.error_procs
      assert_equal configuration.routes, sd.routes.values
      assert_instance_of configuration.logger.class, sd.logger
    end

    should "know its dat tcp server" do
      assert_equal @dat_tcp_server_spy, subject.dat_tcp_server
      assert_not_nil @dat_tcp_server_spy.serve_proc
    end

    should "know its name, pid file and logger" do
      assert_equal subject.server_data.name, subject.name
      assert_equal subject.server_data.pid_file, subject.pid_file
      assert_equal subject.server_data.logger, subject.logger
    end

    should "call listen on its dat tcp server using `listen`" do
      subject.listen
      assert_true @dat_tcp_server_spy.listen_called
    end

    should "use its configured ip and port by default when listening" do
      subject.listen
      assert_equal subject.server_data.ip, @dat_tcp_server_spy.ip
      assert_equal subject.server_data.port, @dat_tcp_server_spy.port
    end

    should "pass any args to its dat tcp server using `listen`" do
      ip, port = Factory.string, Factory.integer
      subject.listen(ip, port)
      assert_equal ip, @dat_tcp_server_spy.ip
      assert_equal port, @dat_tcp_server_spy.port

      file_descriptor = Factory.integer
      subject.listen(file_descriptor)
      assert_equal file_descriptor, @dat_tcp_server_spy.file_descriptor
    end

    should "know its ip, port and file descriptor" do
      assert_equal @dat_tcp_server_spy.ip, subject.ip
      assert_equal @dat_tcp_server_spy.port, subject.port
      subject.listen
      assert_equal @dat_tcp_server_spy.ip, subject.ip
      assert_equal @dat_tcp_server_spy.port, subject.port

      assert_equal @dat_tcp_server_spy.file_descriptor, subject.file_descriptor
      subject.listen(Factory.integer)
      assert_equal @dat_tcp_server_spy.file_descriptor, subject.file_descriptor
    end

    should "call start on its dat tcp server using `start`" do
      client_fds = [ Factory.integer ]
      subject.start(client_fds)
      assert_true @dat_tcp_server_spy.start_called
      assert_equal client_fds, @dat_tcp_server_spy.client_file_descriptors
    end

    should "know its client file descriptors" do
      expected = @dat_tcp_server_spy.client_file_descriptors
      assert_equal expected, subject.client_file_descriptors
      subject.start([ Factory.integer ])
      expected = @dat_tcp_server_spy.client_file_descriptors
      assert_equal expected, subject.client_file_descriptors
    end

    should "call pause on its dat tcp server using `pause`" do
      wait = Factory.boolean
      subject.pause(wait)
      assert_true @dat_tcp_server_spy.pause_called
      assert_equal wait, @dat_tcp_server_spy.waiting_for_pause
    end

    should "call stop on its dat tcp server using `stop`" do
      wait = Factory.boolean
      subject.stop(wait)
      assert_true @dat_tcp_server_spy.stop_called
      assert_equal wait, @dat_tcp_server_spy.waiting_for_stop
    end

    should "call halt on its dat tcp server using `halt`" do
      wait = Factory.boolean
      subject.halt(wait)
      assert_true @dat_tcp_server_spy.halt_called
      assert_equal wait, @dat_tcp_server_spy.waiting_for_halt
    end

    should "know if its been paused" do
      assert_false subject.paused?
      subject.listen
      assert_true subject.paused?
      subject.start
      assert_false subject.paused?
      subject.pause
      assert_true subject.paused?
    end

  end

  class ConfigureTCPServerTests < InitTests
    desc "configuring its tcp server"
    setup do
      @tcp_server = TCPServerSpy.new
      Assert.stub(@dat_tcp_server_spy, :listen) do |*args, &block|
        @configure_tcp_server_proc = block
      end
      @server.listen
      @configure_tcp_server_proc.call(@tcp_server)
    end
    subject{ @tcp_server }

    should "set the TCP_NODELAY option" do
      expected = [ ::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY, true ]
      assert_includes expected, @tcp_server.set_socket_option_calls
    end

  end

  class ServeTests < InitTests
    desc "serve"
    setup do
      @socket = Factory.binary

      @connection = FakeConnection.new
      Assert.stub(Connection, :new).with(@socket){ @connection }

      @worker_spy = WorkerSpy.new
      Assert.stub(Sanford::Worker, :new).tap do |s|
        s.with(@server.server_data, @connection){ @worker_spy }
      end

      @serve_proc = @dat_tcp_server_spy.serve_proc
    end
    subject{ @serve_proc }

    should "run a worker when called with a socket" do
      Assert.stub(@server.server_data, :receives_keep_alive){ false }
      @connection.read_data = Factory.boolean
      assert_false @worker_spy.run_called
      subject.call(@socket)
      assert_true @worker_spy.run_called
    end

    should "not run a keep-alive connection when configured to receive them" do
      Assert.stub(@server.server_data, :receives_keep_alive){ true }
      @connection.read_data = nil # nothing to read makes it a keep-alive
      assert_false @worker_spy.run_called
      subject.call(@socket)
      assert_false @worker_spy.run_called
    end

    should "run a keep-alive connection when configured to receive them" do
      Assert.stub(@server.server_data, :receives_keep_alive){ false }
      @connection.read_data = nil # nothing to read makes it a keep-alive
      assert_false @worker_spy.run_called
      subject.call(@socket)
      assert_true @worker_spy.run_called
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

  class ConfigurationTests < UnitTests
    include NsOptions::AssertMacros

    desc "Configuration"
    setup do
      @configuration = Configuration.new.tap do |c|
        c.name Factory.string
        c.ip Factory.string
        c.port Factory.integer
      end
    end
    subject{ @configuration }

    should have_options :name, :ip, :port, :pid_file
    should have_options :receives_keep_alive
    should have_options :verbose_logging, :logger
    should have_accessors :init_procs, :error_procs
    should have_accessors :router
    should have_readers :template_source
    should have_imeths :set_template_source
    should have_imeths :routes
    should have_imeths :to_hash
    should have_imeths :valid?, :validate!

    should "be an ns-options proxy" do
      assert_includes NsOptions::Proxy, subject.class
    end

    should "default its options" do
      config = Configuration.new
      assert_nil config.name
      assert_equal '0.0.0.0', config.ip
      assert_nil config.port
      assert_nil config.pid_file

      assert_false config.receives_keep_alive

      assert_true config.verbose_logging
      assert_instance_of Sanford::NullLogger, config.logger

      assert_equal [], config.init_procs
      assert_equal [], config.error_procs

      assert_instance_of Sanford::NullTemplateSource, config.template_source
      assert_instance_of Sanford::Router, config.router
      assert_empty config.router.routes
    end

    should "not be valid by default" do
      assert_false subject.valid?
    end

    should "allow setting its template source" do
      new_path = Factory.string
      yielded = nil
      subject.set_template_source(new_path){ |s| yielded = s }
      assert_instance_of Sanford::TemplateSource, subject.template_source
      assert_equal new_path, subject.template_source.path
      assert_equal subject.template_source, yielded
    end

    should "allow only setting the template source path" do
      new_path = Factory.string
      subject.set_template_source(new_path)
      assert_instance_of Sanford::TemplateSource, subject.template_source
      assert_equal new_path, subject.template_source.path
    end

    should "know its routes" do
      assert_equal subject.router.routes, subject.routes
      subject.router.service(Factory.string, TestHandler.to_s)
      assert_equal subject.router.routes, subject.routes
    end

    should "include its routes, error procs and template source in its hash" do
      config_hash = subject.to_hash
      assert_equal subject.error_procs, config_hash[:error_procs]
      assert_equal subject.routes, config_hash[:routes]
      assert_equal subject.template_source, config_hash[:template_source]
    end

    should "call its init procs when validated" do
      called = false
      subject.init_procs << proc{ called = true }
      subject.validate!
      assert_true called
    end

    should "ensure its required options have been set when validated" do
      subject.name = nil
      assert_raises(InvalidError){ subject.validate! }
      subject.name = Factory.string

      subject.ip = nil
      assert_raises(InvalidError){ subject.validate! }
      subject.ip = Factory.string

      subject.port = nil
      assert_raises(InvalidError){ subject.validate! }
      subject.port = Factory.integer

      assert_nothing_raised{ subject.validate! }
    end

    should "validate its routes when validated" do
      subject.router.service(Factory.string, TestHandler.to_s)
      subject.routes.each{ |route| assert_nil route.handler_class }
      subject.validate!
      subject.routes.each{ |route| assert_not_nil route.handler_class }
    end

    should "be valid after being validated" do
      assert_false subject.valid?
      subject.validate!
      assert_true subject.valid?
    end

    should "only be able to be validated once" do
      called = 0
      subject.init_procs << proc{ called += 1 }
      subject.validate!
      assert_equal 1, called
      subject.validate!
      assert_equal 1, called
    end

  end

  TestHandler = Class.new

  class TCPServerSpy
    attr_reader :set_socket_option_calls

    def initialize
      @set_socket_option_calls = []
    end

    def setsockopt(*args)
      @set_socket_option_calls << args
    end
  end

  class WorkerSpy
    attr_reader :run_called

    def initialize
      @run_called = false
    end

    def run
      @run_called = true
    end
  end

end
