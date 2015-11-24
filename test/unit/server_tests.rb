require 'assert'
require 'sanford/server'

require 'dat-tcp/server_spy'
require 'much-plugin'
require 'ns-options/assert_macros'
require 'sanford/route'

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
    should have_imeths :worker_class, :worker_params
    should have_imeths :num_workers, :workers
    should have_imeths :verbose_logging, :logger
    should have_imeths :shutdown_timeout
    should have_imeths :init, :error
    should have_imeths :router, :template_source

    should "use much-plugin" do
      assert_includes MuchPlugin, Sanford::Server
    end

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
      exp = Pathname.new(new_pid_file)
      assert_equal exp, subject.configuration.pid_file
      assert_equal exp, subject.pid_file
    end

    should "allow reading/writing its configuration receives keep alive" do
      new_keep_alive = Factory.boolean
      subject.receives_keep_alive(new_keep_alive)
      assert_equal new_keep_alive, subject.configuration.receives_keep_alive
      assert_equal new_keep_alive, subject.receives_keep_alive
    end

    should "allow reading/writing its configuration worker class" do
      new_worker_class = Class.new
      subject.worker_class(new_worker_class)
      assert_equal new_worker_class, subject.configuration.worker_class
      assert_equal new_worker_class, subject.worker_class
    end

    should "allow reading/writing its configuration worker params" do
      new_worker_params = { Factory.string => Factory.string }
      subject.worker_params(new_worker_params)
      assert_equal new_worker_params, subject.configuration.worker_params
      assert_equal new_worker_params, subject.worker_params
    end

    should "allow reading/writing its configuration num workers" do
      new_num_workers = Factory.integer
      subject.num_workers(new_num_workers)
      assert_equal new_num_workers, subject.configuration.num_workers
      assert_equal new_num_workers, subject.num_workers
    end

    should "alias workers as num workers" do
      new_workers = Factory.integer
      subject.workers(new_workers)
      assert_equal new_workers, subject.configuration.num_workers
      assert_equal new_workers, subject.workers
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

    should "allow reading/writing its configuration shutdown timeout" do
      new_shutdown_timeout = Factory.integer
      subject.shutdown_timeout(new_shutdown_timeout)
      assert_equal new_shutdown_timeout, subject.configuration.shutdown_timeout
      assert_equal new_shutdown_timeout, subject.shutdown_timeout
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
      new_template_source = Factory.string
      subject.template_source(new_template_source)
      assert_equal new_template_source, subject.configuration.template_source
      assert_equal new_template_source, subject.template_source
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @server_class.name Factory.string
      @server_class.ip Factory.string
      @server_class.port Factory.integer
      @server_class.num_workers Factory.integer
      @server_class.worker_params(Factory.string => Factory.string)
      @server_class.shutdown_timeout Factory.integer

      @error_procs = Factory.integer(3).times.map{ proc{} }
      @error_procs.each{ |p| @server_class.error(&p) }

      @server_class.router do
        service Factory.string, TestHandler.to_s
      end

      @dtcp_spy = nil
      Assert.stub(DatTCP::Server, :new) do |*args|
        @dtcp_spy = DatTCP::ServerSpy.new(*args)
      end

      @server = @server_class.new
    end
    subject{ @server }

    should have_readers :server_data, :dat_tcp_server
    should have_imeths :name, :ip, :port
    should have_imeths :file_descriptor, :client_file_descriptors
    should have_imeths :configured_ip, :configured_port
    should have_imeths :pid_file, :logger, :router, :template_source
    should have_imeths :listen, :start, :pause, :stop, :halt
    should have_imeths :paused?

    should "have validated its configuration" do
      assert_true subject.class.configuration.valid?
    end

    should "know its server data" do
      configuration = subject.class.configuration
      data = subject.server_data

      assert_instance_of Sanford::ServerData, data
      assert_equal configuration.name,                data.name
      assert_equal configuration.ip,                  data.ip
      assert_equal configuration.port,                data.port
      assert_equal configuration.worker_class,        data.worker_class
      assert_equal configuration.worker_params,       data.worker_params
      assert_equal configuration.verbose_logging,     data.verbose_logging
      assert_equal configuration.receives_keep_alive, data.receives_keep_alive
      assert_equal configuration.error_procs,         data.error_procs
      assert_equal configuration.routes,              data.routes.values

      assert_instance_of configuration.logger.class, data.logger
    end

    should "know its dat tcp server" do
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

      assert_equal @dtcp_spy, subject.dat_tcp_server
    end

    should "demeter its server data" do
      assert_equal subject.server_data.name, subject.name
      assert_equal subject.server_data.ip, subject.configured_ip
      assert_equal subject.server_data.port, subject.configured_port
      assert_equal subject.server_data.pid_file, subject.pid_file
    end

    should "know its logger, router and template source" do
      assert_equal subject.server_data.logger,          subject.logger
      assert_equal subject.server_data.router,          subject.router
      assert_equal subject.server_data.template_source, subject.template_source
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

  class ConfigurationTests < UnitTests
    include NsOptions::AssertMacros

    desc "Configuration"
    setup do
      @configuration = Configuration.new.tap do |c|
        c.name Factory.string
        c.ip   Factory.string
        c.port Factory.integer
      end
    end
    subject{ @configuration }

    should have_options :name, :ip, :port, :pid_file
    should have_options :receives_keep_alive
    should have_options :verbose_logging, :logger
    should have_options :template_source
    should have_accessors :init_procs, :error_procs
    should have_accessors :worker_class, :worker_params, :num_workers
    should have_accessors :shutdown_timeout
    should have_accessors :router
    should have_imeths :routes
    should have_imeths :to_hash
    should have_imeths :valid?, :validate!

    should "be an ns-options proxy" do
      assert_includes NsOptions::Proxy, subject.class
    end

    should "know its default num workers" do
      assert_equal 4, Configuration::DEFAULT_NUM_WORKERS
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
      assert_instance_of Sanford::NullTemplateSource, config.template_source

      assert_equal DefaultWorker, config.worker_class
      assert_nil config.worker_params
      assert_equal Configuration::DEFAULT_NUM_WORKERS, config.num_workers

      assert_nil config.shutdown_timeout

      assert_equal [], config.init_procs
      assert_equal [], config.error_procs

      assert_instance_of Sanford::Router, config.router
      assert_empty config.router.routes
    end

    should "not be valid by default" do
      assert_false subject.valid?
    end

    should "know its routes" do
      assert_equal subject.router.routes, subject.routes
      subject.router.service(Factory.string, TestHandler.to_s)
      assert_equal subject.router.routes, subject.routes
    end

    should "include its procs and router/routes in its `to_hash`" do
      config_hash = subject.to_hash
      assert_equal subject.worker_class,     config_hash[:worker_class]
      assert_equal subject.worker_params,    config_hash[:worker_params]
      assert_equal subject.num_workers,      config_hash[:num_workers]
      assert_equal subject.shutdown_timeout, config_hash[:shutdown_timeout]
      assert_equal subject.init_procs,       config_hash[:init_procs]
      assert_equal subject.error_procs,      config_hash[:error_procs]
      assert_equal subject.router,           config_hash[:router]
      assert_equal subject.routes,           config_hash[:routes]
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

    should "validate its worker class when validated" do
      subject.worker_class = Module.new
      assert_raises(InvalidError){ subject.validate! }

      subject.worker_class = Class.new
      assert_raises(InvalidError){ subject.validate! }
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

end
