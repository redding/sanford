# Sanford's Host mixin is used to define service hosts. When mixed into a class
# it provides the interface for configuring the service host and for adding
# versioned services. It also contains the logic for routing a request to a
# a service handler.
#
# Options:
# * `hostname`  - The string for the hostname that the TCP Server should bind
#                 to. This defaults to '0.0.0.0'.
# * `port`      - The integer for the port that the TCP Server should bind to.
#                 This isn't defaulted and must be provided.
# * `pid_dir`   - The directory to write the PID file to. This is defaulted to
#                 Dir.pwd.
# * `logger`    - The logger to use if the Sanford server logs messages. This is
#                 defaulted to an instance of Ruby's Logger.
#
require 'logger'
require 'ns-options'
require 'pathname'

require 'sanford/config'
require 'sanford/service_handler'

module Sanford

  module Host

    # Notes:
    # * When Host is included on a class, it needs to mixin NsOptions and define
    #   the options directly on the class (instead of on the Host module).
    #   Otherwise, NsOptions will not work correctly for the class.
    def self.included(host_class)
      host_class.class_eval do
        include NsOptions
        extend Sanford::Host::ClassMethods

        options :config do
          option :hostname, String,   :default => '0.0.0.0'
          option :port,     Integer
          option :pid_dir,  Pathname, :default => Dir.pwd
          option :logger,             :default => nil

          option :versioned_services, Hash, :default => {}
        end
      end
      Sanford.config.hosts.add(host_class)
    end

    attr_reader :name

    # Notes:
    # * The `initialize` takes the values configured on the class and merges
    #   the passed in options. This is used to set the individual instance's
    #   configuration (which allows overwriting options like the port).
    def initialize(options = nil)
      options = self.remove_nil_values(options)
      config_options = self.class.config.to_hash.merge(options)
      @name = self.class.name
      self.config.apply(config_options)
      raise(Sanford::InvalidHost.new(self.class)) if !self.port
    end

    [ :hostname, :port, :pid_dir, :logger ].each do |name|

      define_method(name) do
        self.config.send(name)
      end

    end

    # Notes:
    # * We catch :halt here so that the service handler helper method `halt` can
    #   throw it and have the code jump here. If the `halt` method isn't used,
    #   the block wraps the return value of the handler's `run` method to be the
    #   expected [ status, result ] format.
    def route(request)
      services = self.config.versioned_services[request.service_version] || {}
      handler_class_name = services[request.service_name]
      raise Sanford::NotFound if !handler_class_name
      handler_class = Sanford::ServiceHandler.constantize(handler_class_name)
      raise Sanford::NoHandlerClass.new(self, handler_class_name) if !handler_class
      handler = handler_class.new(self.logger, request)
      catch(:halt) do
        handler.init
        returned_value = handler.run
        [ :success, returned_value ]
      end
    end

    protected

    def remove_nil_values(options)
      (options || {}).inject({}) do |hash, (k, v)|
        hash.merge!({ k => v }) if !v.nil?
        hash
      end
    end

    module ClassMethods

      def configure(&block)
        self.config.define(&block)
      end

      def name(value = nil)
        @name = value if value
        @name || self.to_s
      end

      def version(name, &block)
        version_group = Sanford::Host::VersionGroup.new(name, &block)
        self.config.versioned_services.merge!(version_group.to_hash)
      end

    end

    class VersionGroup
      attr_reader :name, :services

      def initialize(name, &definition_block)
        @name = name
        @services = {}
        self.instance_eval(&definition_block)
      end

      def service(service_name, handler_class_name)
        @services[service_name] = handler_class_name
      end

      def to_hash
        { self.name => self.services }
      end

    end

  end

end
