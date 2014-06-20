require 'dat-tcp'
require 'ns-options'
require 'ns-options/boolean'
require 'sanford-protocol'
require 'socket'
require 'sanford/logger'
require 'sanford/router'
require 'sanford/template_source'
require 'sanford/worker'

module Sanford

  module Server

    def self.included(klass)
      klass.class_eval do
        extend ClassMethods
        include InstanceMethods
      end
    end

    module InstanceMethods

      attr_reader :config_data, :dat_tcp_server

      def initialize
        self.class.configuration.validate!
        @config_data = ConfigData.new(self.class.configuration.to_hash)
        @dat_tcp_server = DatTCP::Server.new{ |socket| serve(socket) }
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

      def listen(*args)
        args = [ @config_data.ip, @config_data.port ] if args.empty?
        @dat_tcp_server.listen(*args) do |server_socket|
          configure_tcp_server(server_socket)
        end
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

      private

      def serve(socket)
        connection = Connection.new(socket)
        if !keep_alive_connection?(connection)
          Sanford::Worker.new(@config_data, connection).run
        end
      end

      def keep_alive_connection?(connection)
        @config_data.receives_keep_alive && connection.peek_data.empty?
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

      def router(value = nil, &block)
        self.configuration.router = value if !value.nil?
        self.configuration.router.instance_eval(&block) if block
        self.configuration.router
      end

      def set_template_source(path, &block)
        self.configuration.set_template_source(path, &block)
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

    class ConfigData
      # The server uses this to "compile" the configuration data for speed.
      # NsOptions is relatively slow everytime an option is read. To avoid this,
      # we read the options one time here and memoize their values. This way,
      # we don't pay the NsOptions overhead when reading them while handling
      # a request.

      attr_reader :name
      attr_reader :ip, :port
      attr_reader :logger, :verbose_logging
      attr_reader :receives_keep_alive
      attr_reader :error_procs
      attr_reader :routes

      def initialize(args = nil)
        args ||= {}
        @name = args[:name]
        @ip   = args[:ip]
        @port = args[:port]
        @logger = args[:logger]
        @verbose_logging = !!args[:verbose_logging]
        @receives_keep_alive = !!args[:receives_keep_alive]
        @error_procs = args[:error_procs] || []
        @routes = (args[:routes] || []).inject({}) do |h, route|
          h.merge(route.name => route)
        end
      end

      def route_for(name)
        @routes[name] || raise(NotFoundError, "no service named '#{name}'")
      end
    end

    class Configuration
      include NsOptions::Proxy

      option :name,     String
      option :ip,       String, :default => '0.0.0.0'
      option :port,     Integer
      option :pid_file, Pathname

      option :receives_keep_alive, NsOptions::Boolean, :default => false

      option :verbose_logging, :default => true
      option :logger,          :default => proc{ Sanford::NullLogger.new }

      attr_accessor :init_procs, :error_procs
      attr_accessor :router
      attr_reader :template_source

      def initialize(values = nil)
        super(values)
        @init_procs, @error_procs = [], []
        @template_source = Sanford::NullTemplateSource.new
        @router = Sanford::Router.new
        @valid = nil
      end

      def set_template_source(path, &block)
        block ||= proc{ }
        @template_source = TemplateSource.new(path).tap(&block)
      end

      def routes
        @router.routes
      end

      def to_hash
        super.merge({
          :error_procs => self.error_procs,
          :routes => self.routes
        })
      end

      def valid?
        !!@valid
      end

      def validate!
        return @valid if !@valid.nil?
        self.init_procs.each(&:call)
        self.routes.each(&:validate!)
        @valid = true
      end
    end

  end

  NotFoundError = Class.new(RuntimeError)

end
