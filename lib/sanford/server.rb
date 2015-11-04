require 'dat-tcp'
require 'ns-options'
require 'ns-options/boolean'
require 'pathname'
require 'sanford-protocol'
require 'socket'
require 'sanford/logger'
require 'sanford/router'
require 'sanford/server_data'
require 'sanford/template_source'
require 'sanford/connection_handler'

module Sanford

  module Server

    def self.included(klass)
      klass.class_eval do
        extend ClassMethods
        include InstanceMethods
      end
    end

    module InstanceMethods

      attr_reader :server_data, :dat_tcp_server

      def initialize
        self.class.configuration.validate!
        @server_data = ServerData.new(self.class.configuration.to_hash)
        @dat_tcp_server = build_dat_tcp_server
      rescue InvalidError => exception
        exception.set_backtrace(caller)
        raise exception
      end

      def name
        @server_data.name
      end

      def ip
        @dat_tcp_server.ip
      end

      def port
        @dat_tcp_server.port
      end

      def file_descriptor
        @dat_tcp_server.file_descriptor
      end

      def client_file_descriptors
        @dat_tcp_server.client_file_descriptors
      end

      def configured_ip
        @server_data.ip
      end

      def configured_port
        @server_data.port
      end

      def pid_file
        @server_data.pid_file
      end

      def logger
        @server_data.logger
      end

      def router
        @server_data.router
      end

      def template_source
        @server_data.template_source
      end

      def listen(*args)
        args = [@server_data.ip, @server_data.port] if args.empty?
        @dat_tcp_server.listen(*args) do |server_socket|
          configure_tcp_server(server_socket)
        end
        @server_data.ip   = self.ip
        @server_data.port = self.port
      end

      def start(*args)
        @dat_tcp_server.start(*args)
      end

      def pause(*args)
        @dat_tcp_server.pause(*args)
      end

      def stop(*args)
        @dat_tcp_server.stop(*args)
      end

      def halt(*args)
        @dat_tcp_server.halt(*args)
      end

      def paused?
        @dat_tcp_server.listening? && !@dat_tcp_server.running?
      end

      private

      def build_dat_tcp_server
        s = DatTCP::Server.new{ |socket| serve(socket) }

        # add any configured callbacks
        self.server_data.worker_start_procs.each{ |p| s.on_worker_start(&p) }
        self.server_data.worker_shutdown_procs.each{ |p|  s.on_worker_shutdown(&p) }
        self.server_data.worker_sleep_procs.each{ |p| s.on_worker_sleep(&p) }
        self.server_data.worker_wakeup_procs.each{ |p| s.on_worker_wakeup(&p) }

        s
      end

      def serve(socket)
        connection = Connection.new(socket)
        if !keep_alive_connection?(connection)
          Sanford::ConnectionHandler.new(@server_data, connection).run
        end
      end

      def keep_alive_connection?(connection)
        @server_data.receives_keep_alive && connection.peek_data.empty?
      end

      # TCP_NODELAY is set to disable buffering. In the case of Sanford
      # communication, we have all the information we need to send up front and
      # are closing the connection, so it doesn't need to buffer.
      # See http://linux.die.net/man/7/tcp

      def configure_tcp_server(tcp_server)
        tcp_server.setsockopt(::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY, true)
      end

    end

    module ClassMethods

      def configuration
        @configuration ||= Configuration.new
      end

      def name(*args)
        self.configuration.name *args
      end

      def ip(*args)
        self.configuration.ip *args
      end

      def port(*args)
        self.configuration.port *args
      end

      def pid_file(*args)
        self.configuration.pid_file *args
      end

      def receives_keep_alive(*args)
        self.configuration.receives_keep_alive *args
      end

      def verbose_logging(*args)
        self.configuration.verbose_logging *args
      end

      def logger(*args)
        self.configuration.logger *args
      end

      def init(&block)
        self.configuration.init_procs << block
      end

      def error(&block)
        self.configuration.error_procs << block
      end

      def on_worker_start(&block)
        self.configuration.worker_start_procs << block
      end

      def on_worker_shutdown(&block)
        self.configuration.worker_shutdown_procs << block
      end

      def on_worker_sleep(&block)
        self.configuration.worker_sleep_procs << block
      end

      def on_worker_wakeup(&block)
        self.configuration.worker_wakeup_procs << block
      end

      def router(value = nil, &block)
        self.configuration.router = value if !value.nil?
        self.configuration.router.instance_eval(&block) if block
        self.configuration.router
      end

      def template_source(*args)
        self.configuration.template_source(*args)
      end

    end

    class Connection
      DEFAULT_TIMEOUT = 1

      attr_reader :timeout

      def initialize(socket)
        @socket     = socket
        @connection = Sanford::Protocol::Connection.new(@socket)
        @timeout    = (ENV['SANFORD_TIMEOUT'] || DEFAULT_TIMEOUT).to_f
      end

      def read_data
        @connection.read(@timeout)
      end

      def write_data(data)
        TCPCork.apply(@socket)
        @connection.write data
        TCPCork.remove(@socket)
      end

      def peek_data
        @connection.peek(@timeout)
      end

      def close_write
        @connection.close_write
      end
    end

    module TCPCork
      # On Linux, use TCP_CORK to better control how the TCP stack
      # packetizes our stream. This improves both latency and throughput.
      # TCP_CORK disables Nagle's algorithm, which is ideal for sporadic
      # traffic (like Telnet) but is less optimal for HTTP. Sanford is similar
      # to HTTP, it doesn't receive sporadic packets, it has all its data
      # come in at once.
      # For more information: http://baus.net/on-tcp_cork

      if RUBY_PLATFORM =~ /linux/
        # 3 == TCP_CORK
        def self.apply(socket)
          socket.setsockopt(::Socket::IPPROTO_TCP, 3, true)
        end

        def self.remove(socket)
          socket.setsockopt(::Socket::IPPROTO_TCP, 3, false)
        end
      else
        def self.apply(socket)
        end

        def self.remove(socket)
        end
      end
    end

    class Configuration
      include NsOptions::Proxy

      option :name,     String,  :required => true
      option :ip,       String,  :required => true, :default => '0.0.0.0'
      option :port,     Integer, :required => true
      option :pid_file, Pathname

      option :receives_keep_alive, NsOptions::Boolean, :default => false

      option :verbose_logging, :default => true
      option :logger,          :default => proc{ NullLogger.new }
      option :template_source, :default => proc{ NullTemplateSource.new }

      attr_accessor :init_procs, :error_procs
      attr_accessor :router
      attr_reader :worker_start_procs, :worker_shutdown_procs
      attr_reader :worker_sleep_procs, :worker_wakeup_procs

      def initialize(values = nil)
        super(values)
        @init_procs, @error_procs = [], []
        @worker_start_procs, @worker_shutdown_procs = [], []
        @worker_sleep_procs, @worker_wakeup_procs   = [], []
        @router = Sanford::Router.new
        @valid  = nil
      end

      def routes
        @router.routes
      end

      def to_hash
        super.merge({
          :init_procs            => self.init_procs,
          :error_procs           => self.error_procs,
          :worker_start_procs    => self.worker_start_procs,
          :worker_shutdown_procs => self.worker_shutdown_procs,
          :worker_sleep_procs    => self.worker_sleep_procs,
          :worker_wakeup_procs   => self.worker_wakeup_procs,
          :router                => self.router,
          :routes                => self.routes
        })
      end

      def valid?
        !!@valid
      end

      def validate!
        return @valid if !@valid.nil?
        self.init_procs.each(&:call)
        if !self.required_set?
          raise InvalidError, "a name, ip and port must be configured"
        end
        self.routes.each(&:validate!)
        @valid = true
      end
    end

    InvalidError = Class.new(RuntimeError)

  end

end
