require 'assert'
require 'sanford/server'

require 'dat-tcp/server_spy'
require 'much-plugin'
require 'sanford/logger'
require 'sanford/router'
require 'sanford/template_source'

module Sanford::Server

  class UnitTests < Assert::Context
    desc "Sanford::Server"
    setup do
      @server_class = Class.new{ include Sanford::Server }
    end
    subject{ @server_class }

    should have_imeths :config
    should have_imeths :name, :ip, :port, :pid_file, :shutdown_timeout
    should have_imeths :worker_class, :worker_params, :num_workers, :workers
    should have_imeths :init, :error, :template_source, :logger, :router
    should have_imeths :receives_keep_alive, :verbose_logging

    should "use much-plugin" do
      assert_includes MuchPlugin, Sanford::Server
    end

    should "allow setting its config values" do
      config = subject.config

      exp = Factory.string
      subject.name exp
      assert_equal exp, config.name

      exp = Factory.string
      subject.ip exp
      assert_equal exp, config.ip

      exp = Factory.integer
      subject.port exp
      assert_equal exp, config.port

      exp = Factory.file_path
      subject.pid_file exp
      assert_equal exp, config.pid_file

      exp = Factory.integer
      subject.shutdown_timeout exp
      assert_equal exp, config.shutdown_timeout

      exp = Class.new
      subject.worker_class exp
      assert_equal exp, subject.config.worker_class

      exp = { Factory.string => Factory.string }
      subject.worker_params exp
      assert_equal exp, subject.config.worker_params

      exp = Factory.integer
      subject.num_workers(exp)
      assert_equal exp, subject.config.num_workers
      assert_equal exp, subject.workers

      exp = proc{ }
      assert_equal 0, config.init_procs.size
      subject.init(&exp)
      assert_equal 1, config.init_procs.size
      assert_equal exp, config.init_procs.first

      exp = proc{ }
      assert_equal 0, config.error_procs.size
      subject.error(&exp)
      assert_equal 1, config.error_procs.size
      assert_equal exp, config.error_procs.first

      exp = Sanford::TemplateSource.new(Factory.path)
      subject.template_source exp
      assert_equal exp, config.template_source

      exp = Logger.new(STDOUT)
      subject.logger exp
      assert_equal exp, config.logger

      exp = Factory.boolean
      subject.receives_keep_alive exp
      assert_equal exp, config.receives_keep_alive

      exp = Factory.boolean
      subject.verbose_logging exp
      assert_equal exp, config.verbose_logging
    end

    should "have a router by default and allow overriding it" do
      assert_kind_of Sanford::Router, subject.router

      new_router = Sanford::Router.new
      subject.router new_router
      assert_same new_router, subject.config.router
      assert_same new_router, subject.router
    end

    should "allow configuring the router by passing a block to `router`" do
      block_scope = nil
      subject.router{ block_scope = self }
      assert_equal subject.router, block_scope
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @server_class.name Factory.string
      @server_class.ip Factory.string
      @server_class.port Factory.integer
      @server_class.shutdown_timeout Factory.integer
      @server_class.worker_params(Factory.string => Factory.string)
      @server_class.num_workers Factory.integer

      @error_procs = Factory.integer(3).times.map{ proc{} }
      @error_procs.each{ |p| @server_class.error(&p) }

      @dtcp_spy = nil
      Assert.stub(DatTCP::Server, :new) do |*args|
        @dtcp_spy = DatTCP::ServerSpy.new(*args)
      end

      @server = @server_class.new
    end
    subject{ @server }

    should have_readers :server_data
    should have_imeths :ip, :port, :file_descriptor, :client_file_descriptors
    should have_imeths :name, :configured_ip, :configured_port, :process_label
    should have_imeths :pid_file, :logger, :router, :template_source
    should have_imeths :listen, :start, :pause, :stop, :halt
    should have_imeths :listening?, :running?, :paused?

    should "have validated its config" do
      assert_true @server_class.config.valid?
    end

    should "know its server data" do
      config = @server_class.config
      data   = subject.server_data

      assert_instance_of Sanford::ServerData, data

      assert_equal config.name,             data.name
      assert_equal config.ip,               data.ip
      assert_equal config.port,             data.port
      assert_equal config.pid_file,         data.pid_file
      assert_equal config.shutdown_timeout, data.shutdown_timeout
      assert_equal config.worker_class,     data.worker_class
      assert_equal config.worker_params,    data.worker_params
      assert_equal config.num_workers,      data.num_workers
      assert_equal config.error_procs,      data.error_procs

      assert_instance_of config.logger.class, data.logger
      assert_instance_of config.router.class, data.router

      assert_equal config.template_source,     data.template_source
      assert_equal config.verbose_logging,     data.verbose_logging
      assert_equal config.receives_keep_alive, data.receives_keep_alive

      assert_equal config.routes, data.routes.values
    end

    should "build a dat-tcp server" do
      data = subject.server_data

      assert_not_nil @dtcp_spy
      assert_equal data.worker_class,     @dtcp_spy.worker_class
      assert_equal data.num_workers,      @dtcp_spy.num_workers
      assert_equal data.dtcp_logger,      @dtcp_spy.logger
      assert_equal data.shutdown_timeout, @dtcp_spy.shutdown_timeout
      exp = data.worker_params.merge({
        :sanford_server_data => data
      })
      assert_equal exp, @dtcp_spy.worker_params
    end

    should "demeter its server data" do
      data = subject.server_data

      assert_equal data.name,            subject.name
      assert_equal data.ip,              subject.configured_ip
      assert_equal data.port,            subject.configured_port
      assert_equal data.process_label,   subject.process_label
      assert_equal data.pid_file,        subject.pid_file
      assert_equal data.logger,          subject.logger
      assert_equal data.router,          subject.router
      assert_equal data.template_source, subject.template_source
    end

    should "call listen on its dat tcp server using `listen`" do
      subject.listen
      assert_true @dtcp_spy.listen_called
    end

    should "use its configured ip and port by default when listening" do
      subject.listen
      assert_equal subject.server_data.ip,   @dtcp_spy.ip
      assert_equal subject.server_data.port, @dtcp_spy.port
    end

    should "write its ip and port back to its server data" do
      ip   = Factory.string
      port = Factory.integer
      assert_not_equal ip,   subject.server_data.ip
      assert_not_equal port, subject.server_data.port
      subject.listen(ip, port)
      assert_equal ip,   subject.server_data.ip
      assert_equal port, subject.server_data.port
    end

    should "pass any args to its dat tcp server using `listen`" do
      ip, port = Factory.string, Factory.integer
      subject.listen(ip, port)
      assert_equal ip,   @dtcp_spy.ip
      assert_equal port, @dtcp_spy.port

      file_descriptor = Factory.integer
      subject.listen(file_descriptor)
      assert_equal file_descriptor, @dtcp_spy.file_descriptor
    end

    should "know its ip, port and file descriptor" do
      assert_equal @dtcp_spy.ip,   subject.ip
      assert_equal @dtcp_spy.port, subject.port
      subject.listen
      assert_equal @dtcp_spy.ip,   subject.ip
      assert_equal @dtcp_spy.port, subject.port

      assert_equal @dtcp_spy.file_descriptor, subject.file_descriptor
      subject.listen(Factory.integer)
      assert_equal @dtcp_spy.file_descriptor, subject.file_descriptor
    end

    should "call start on its dat tcp server using `start`" do
      client_fds = [Factory.integer]
      subject.start(client_fds)
      assert_true @dtcp_spy.start_called
      assert_equal client_fds, @dtcp_spy.client_file_descriptors
    end

    should "know its client file descriptors" do
      exp = @dtcp_spy.client_file_descriptors
      assert_equal exp, subject.client_file_descriptors
      subject.start([Factory.integer])
      exp = @dtcp_spy.client_file_descriptors
      assert_equal exp, subject.client_file_descriptors
    end

    should "call pause on its dat tcp server using `pause`" do
      wait = Factory.boolean
      subject.pause(wait)
      assert_true @dtcp_spy.pause_called
      assert_equal wait, @dtcp_spy.waiting_for_pause
    end

    should "call stop on its dat tcp server using `stop`" do
      wait = Factory.boolean
      subject.stop(wait)
      assert_true @dtcp_spy.stop_called
      assert_equal wait, @dtcp_spy.waiting_for_stop
    end

    should "call halt on its dat tcp server using `halt`" do
      wait = Factory.boolean
      subject.halt(wait)
      assert_true @dtcp_spy.halt_called
      assert_equal wait, @dtcp_spy.waiting_for_halt
    end

    should "know if its listening, running or been paused" do
      assert_false subject.listening?
      assert_false subject.running?
      assert_false subject.paused?
      subject.listen
      assert_true subject.listening?
      assert_false subject.running?
      assert_true subject.paused?
      subject.start
      assert_true subject.listening?
      assert_true subject.running?
      assert_false subject.paused?
      subject.pause
      assert_true subject.listening?
      assert_false subject.running?
      assert_true subject.paused?
    end

  end

  class ConfigureTCPServerTests < InitTests
    desc "configuring its tcp server"
    setup do
      @tcp_server = TCPServerSpy.new
      Assert.stub(@dtcp_spy, :listen) do |*args, &block|
        @configure_tcp_server_proc = block
      end
      @server.listen
      @configure_tcp_server_proc.call(@tcp_server)
    end
    subject{ @tcp_server }

    should "set the TCP_NODELAY option" do
      exp = [ ::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY, true ]
      assert_includes exp, @tcp_server.set_socket_option_calls
    end

  end

  class ConfigTests < UnitTests
    desc "Config"
    setup do
      @config_class = Config
      @config = Config.new
    end
    subject{ @config }

    should have_accessors :name, :ip, :port, :pid_file, :shutdown_timeout
    should have_accessors :worker_class, :worker_params, :num_workers
    should have_accessors :init_procs, :error_procs, :template_source, :logger, :router
    should have_accessors :receives_keep_alive, :verbose_logging
    should have_imeths :routes, :valid?, :validate!

    should "know its default attr values" do
      assert_equal 4,         @config_class::DEFAULT_NUM_WORKERS
      assert_equal '0.0.0.0', @config_class::DEFAULT_IP_ADDRESS
    end

    should "default its attrs" do
      assert_nil subject.name

      exp = @config_class::DEFAULT_IP_ADDRESS
      assert_equal exp, subject.ip

      assert_nil subject.port
      assert_nil subject.pid_file
      assert_nil subject.shutdown_timeout

      assert_equal DefaultWorker, subject.worker_class

      assert_nil subject.worker_params

      exp = @config_class::DEFAULT_NUM_WORKERS
      assert_equal exp, subject.num_workers

      assert_equal [], subject.init_procs
      assert_equal [], subject.error_procs

      assert_instance_of Sanford::NullTemplateSource, subject.template_source
      assert_equal ENV['PWD'], subject.template_source.path

      assert_instance_of Sanford::NullLogger, subject.logger
      assert_instance_of Sanford::Router,     subject.router

      assert_equal false, subject.receives_keep_alive
      assert_equal true,  subject.verbose_logging
    end

    should "demeter its router" do
      assert_equal subject.router.routes, subject.routes
    end

    should "not be valid until validate! has been run" do
      assert_false subject.valid?

      subject.name = Factory.string
      subject.ip   = Factory.string
      subject.port = Factory.integer

      subject.validate!
      assert_true subject.valid?
    end

    should "complain if validating and its name/ip/port is nil" do
      subject.name = Factory.string
      subject.ip   = Factory.string
      subject.port = Factory.integer

      a = [:name, :ip, :port].sample
      subject.send("#{a}=", nil)
      assert_raises(InvalidError){ subject.validate! }
    end

    should "complain if validating and its worker class isn't a Worker" do
      subject.name = Factory.string
      subject.ip   = Factory.string
      subject.port = Factory.integer

      subject.worker_class = Module.new
      assert_raises(InvalidError){ subject.validate! }

      subject.worker_class = Class.new
      assert_raises(InvalidError){ subject.validate! }
    end

  end

  class ValidationTests < ConfigTests
    desc "when successfully validated"
    setup do
      @router = Sanford::Router.new
      @router_validate_called = false
      Assert.stub(@router, :validate!){ @router_validate_called = true }

      @config = Config.new.tap do |c|
        c.name   = Factory.string
        c.ip     = Factory.string
        c.port   = Factory.integer
        c.router = @router
      end

      @initialized = false
      @config.init_procs << proc{ @initialized = true }

      @other_initialized = false
      @config.init_procs << proc{ @other_initialized = true }
    end

    should "call its init procs" do
      assert_equal false, @initialized
      assert_equal false, @other_initialized

      subject.validate!

      assert_equal true, @initialized
      assert_equal true, @other_initialized
    end

    should "call validate! on the router" do
      assert_false @router_validate_called

      subject.validate!
      assert_true @router_validate_called
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

  class TCPServerSpy
    attr_reader :set_socket_option_calls

    def initialize
      @set_socket_option_calls = []
    end

    def setsockopt(*args)
      @set_socket_option_calls << args
    end
  end

end
