require 'dat-tcp'
require 'much-plugin'
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

      attr_reader :server_data

      def initialize
        config = self.class.config
        begin
          config.validate!
        rescue InvalidError => exception
          exception.set_backtrace(caller)
          raise exception
        end

        @server_data = ServerData.new({
          :name                => config.name,
          :ip                  => config.ip,
          :port                => config.port,
          :pid_file            => config.pid_file,
          :shutdown_timeout    => config.shutdown_timeout,
          :worker_class        => config.worker_class,
          :worker_params       => config.worker_params,
          :num_workers         => config.num_workers,
          :error_procs         => config.error_procs,
          :template_source     => config.template_source,
          :logger              => config.logger,
          :router              => config.router,
          :receives_keep_alive => config.receives_keep_alive,
          :verbose_logging     => config.verbose_logging,
          :routes              => config.routes
        })

        @dat_tcp_server = DatTCP::Server.new(self.server_data.worker_class, {
          :num_workers      => self.server_data.num_workers,
          :logger           => self.server_data.dtcp_logger,
          :shutdown_timeout => self.server_data.shutdown_timeout,
          :worker_params    => self.server_data.worker_params.merge({
            :sanford_server_data => self.server_data
          })
        })
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

      def config
        @config ||= Config.new
      end

      def name(value = nil)
        self.config.name = value if !value.nil?
        self.config.name
      end

      def ip(value = nil)
        self.config.ip = value if !value.nil?
        self.config.ip
      end

      def port(value = nil)
        self.config.port = value if !value.nil?
        self.config.port
      end

      def pid_file(value = nil)
        self.config.pid_file = value if !value.nil?
        self.config.pid_file
      end

      def shutdown_timeout(value = nil)
        self.config.shutdown_timeout = value if !value.nil?
        self.config.shutdown_timeout
      end

      def worker_class(value = nil)
        self.config.worker_class = value if !value.nil?
        self.config.worker_class
      end

      def worker_params(value = nil)
        self.config.worker_params = value if !value.nil?
        self.config.worker_params
      end

      def num_workers(new_num_workers = nil)
        self.config.num_workers = new_num_workers if new_num_workers
        self.config.num_workers
      end
      alias :workers :num_workers

      def init(&block)
        self.config.init_procs << block
      end

      def error(&block)
        self.config.error_procs << block
      end

      def template_source(value = nil)
        self.config.template_source = value if !value.nil?
        self.config.template_source
      end

      def logger(value = nil)
        self.config.logger = value if !value.nil?
        self.config.logger
      end

      def router(value = nil, &block)
        self.config.router = value if !value.nil?
        self.config.router.instance_eval(&block) if block
        self.config.router
      end

      # flags

      def receives_keep_alive(value = nil)
        self.config.receives_keep_alive = value if !value.nil?
        self.config.receives_keep_alive
      end

      def verbose_logging(value = nil)
        self.config.verbose_logging = value if !value.nil?
        self.config.verbose_logging
      end

    end

    class Config

      DEFAULT_NUM_WORKERS = 4.freeze
      DEFAULT_IP_ADDRESS  = '0.0.0.0'.freeze

      attr_accessor :name, :ip, :port, :pid_file, :shutdown_timeout
      attr_accessor :worker_class, :worker_params, :num_workers
      attr_accessor :init_procs, :error_procs, :template_source, :logger, :router
      attr_accessor :receives_keep_alive, :verbose_logging

      def initialize
        @name             = nil
        @ip               = DEFAULT_IP_ADDRESS
        @port             = nil
        @pid_file         = nil
        @shutdown_timeout = nil
        @worker_class     = DefaultWorker
        @worker_params    = nil
        @num_workers      = DEFAULT_NUM_WORKERS
        @init_procs       = []
        @error_procs      = []
        @template_source  = Sanford::NullTemplateSource.new(ENV['PWD'])
        @logger           = Sanford::NullLogger.new
        @router           = Sanford::Router.new

        @receives_keep_alive = false
        @verbose_logging     = true

        @valid = nil
      end

      def routes
        self.router.routes
      end

      def valid?
        !!@valid
      end

      # for the config to be considered "valid", a few things need to happen.
      # The key here is that this only needs to be done _once_ for each config.

      def validate!
        return @valid if !@valid.nil? # only need to run this once per config

        # ensure all user and plugin configs/settings are applied
        self.init_procs.each(&:call)
        [:name, :ip, :port].each do |a|
          if self.send(a).nil?
            raise InvalidError, "a name, ip and port must be configured"
          end
        end

        # validate the worker class
        if !self.worker_class.kind_of?(Class) || !self.worker_class.include?(Sanford::Worker)
          raise InvalidError, "worker class must include `#{Sanford::Worker}`"
        end

        # validate the router
        self.router.validate!

        @valid = true # if it made it this far, it's valid!
      end

    end

    DefaultWorker = Class.new{ include Sanford::Worker }
    InvalidError  = Class.new(RuntimeError)

  end

end
