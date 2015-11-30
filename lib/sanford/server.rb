require 'dat-tcp'
require 'much-plugin'
require 'ns-options'
require 'ns-options/boolean'
require 'pathname'
require 'sanford-protocol'
require 'socket'
require 'sanford/logger'
require 'sanford/router'
require 'sanford/server_data'
require 'sanford/template_source'
require 'sanford/worker'

module Sanford

  module Server
    include MuchPlugin

    plugin_included do
      extend ClassMethods
      include InstanceMethods
    end

    module InstanceMethods

      attr_reader :server_data, :dat_tcp_server

      def initialize
        self.class.configuration.validate!
        @server_data = ServerData.new(self.class.configuration.to_hash)
        @dat_tcp_server = DatTCP::Server.new(self.server_data.worker_class, {
          :num_workers      => self.server_data.num_workers,
          :logger           => self.server_data.dtcp_logger,
          :shutdown_timeout => self.server_data.shutdown_timeout,
          :worker_params    => self.server_data.worker_params.merge({
            :sanford_server_data => self.server_data
          })
        })
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

      def worker_class(new_worker_class = nil)
        self.configuration.worker_class = new_worker_class if new_worker_class
        self.configuration.worker_class
      end

      def worker_params(new_worker_params = nil)
        self.configuration.worker_params = new_worker_params if new_worker_params
        self.configuration.worker_params
      end

      def num_workers(new_num_workers = nil)
        self.configuration.num_workers = new_num_workers if new_num_workers
        self.configuration.num_workers
      end
      alias :workers :num_workers

      def receives_keep_alive(*args)
        self.configuration.receives_keep_alive *args
      end

      def verbose_logging(*args)
        self.configuration.verbose_logging *args
      end

      def logger(*args)
        self.configuration.logger *args
      end

      def shutdown_timeout(new_timeout = nil)
        self.configuration.shutdown_timeout = new_timeout if new_timeout
        self.configuration.shutdown_timeout
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

      def template_source(*args)
        self.configuration.template_source(*args)
      end

    end

    class Configuration
      include NsOptions::Proxy

      DEFAULT_NUM_WORKERS = 4

      option :name,     String,  :required => true
      option :ip,       String,  :required => true, :default => '0.0.0.0'
      option :port,     Integer, :required => true
      option :pid_file, Pathname

      option :receives_keep_alive, NsOptions::Boolean, :default => false

      option :verbose_logging, :default => true
      option :logger,          :default => proc{ NullLogger.new }
      option :template_source, :default => proc{ NullTemplateSource.new }

      attr_accessor :init_procs, :error_procs
      attr_accessor :worker_class, :worker_params, :num_workers
      attr_accessor :shutdown_timeout
      attr_accessor :router

      def initialize(values = nil)
        super(values)
        @init_procs, @error_procs = [], []
        @worker_class     = DefaultWorker
        @worker_params    = nil
        @num_workers      = DEFAULT_NUM_WORKERS
        @shutdown_timeout = nil
        @router           = Sanford::Router.new
        @valid  = nil
      end

      def routes
        @router.routes
      end

      def to_hash
        super.merge({
          :init_procs       => self.init_procs,
          :error_procs      => self.error_procs,
          :worker_class     => self.worker_class,
          :worker_params    => self.worker_params,
          :num_workers      => self.num_workers,
          :shutdown_timeout => self.shutdown_timeout,
          :router           => self.router,
          :routes           => self.routes
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
        if !self.worker_class.kind_of?(Class) || !self.worker_class.include?(Sanford::Worker)
          raise InvalidError, "worker class must include `#{Sanford::Worker}`"
        end
        self.routes.each(&:validate!)
        @valid = true
      end
    end

    DefaultWorker = Class.new{ include Sanford::Worker }

    InvalidError = Class.new(RuntimeError)

  end

end
