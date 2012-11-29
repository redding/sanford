# Sanford's Host mixin is used to define service hosts. When mixed into a class
# it provides the interface for configuring the service host and for adding
# versioned services. It also contains the logic for routing a request to a
# a service handler.
#
# Options:
# * `name`    - A string for naming this host. This can be used when specifying
#               a host with the rake tasks and will be used to name the PID
#               file. Defaults to the class's name.
# * `ip`      - The string for the ip that the TCP Server should bind to. This
#               defaults to '0.0.0.0'.
# * `port`    - The integer for the port that the TCP Server should bind to.
#               This isn't defaulted and must be provided.
# * `pid_dir` - The directory to write the PID file to. This is defaulted to
#               Dir.pwd.
# * `logger`  - The logger to use if the Sanford server logs messages. This is
#               defaulted to an instance of Ruby's Logger.
#
require 'logger'
require 'ns-options'
require 'pathname'

require 'sanford/config'
require 'sanford/exception_handler'
require 'sanford/exceptions'
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
        extend Sanford::Host::Interface

        options :config do
          option :name,     String,   :default => host_class.to_s
          option :ip,       String,   :default => '0.0.0.0'
          option :port,     Integer
          option :pid_dir,  Pathname, :default => Dir.pwd
          option :logger,             :default => proc{ Sanford::NullLogger.new }

          option :exception_handler,        :default => Sanford::ExceptionHandler
          option :versioned_services, Hash, :default => {}
        end
      end
      Sanford.config.hosts.add(host_class)
    end

    INTERFACE_OPTIONS = [ :name, :ip, :port, :pid_dir, :logger, :exception_handler ]

    # Notes:
    # * The `initialize` takes the values configured on the class and merges
    #   the passed in options. This is used to set the individual instance's
    #   configuration (which allows overwriting options like the port).
    def initialize(options = nil)
      options = self.remove_nil_values(options)
      config_options = self.class.config.to_hash.merge(options)
      self.config.apply(config_options)
      raise(Sanford::InvalidHostError.new(self.class)) if !self.port
    end

    INTERFACE_OPTIONS.each do |name|

      define_method(name) do
        self.config.send(name)
      end

    end

    def run(request)
      request_handler(request).run
    end

    def inspect
      reference = '0x0%x' % (self.object_id << 1)
      "#<#{self.class}:#{reference} ip=#{self.config.ip.inspect} " \
      "port=#{self.config.port.inspect}>"
    end

    protected

    def request_handler(request)
      handler_class(get_handler_class_name(request)).new(self.logger, request)
    end

    def handler_class(class_name_str)
      self.logger.info("  Handler: #{class_name_str.inspect}")
      Sanford::ServiceHandler.constantize(class_name_str).tap do |handler_class|
        raise Sanford::NoHandlerClassError.new(self, class_name_str) if !handler_class
      end
    end

    def get_handler_class_name(request)
      services = self.config.versioned_services[request.version] || {}
      services[request.name].tap do |name|
        raise Sanford::NotFoundError if !name
      end
    end

    def remove_nil_values(options)
      (options || {}).inject({}) do |hash, (k, v)|
        hash.merge!({ k => v }) if !v.nil?
        hash
      end
    end

    module Interface

      INTERFACE_OPTIONS.each do |name|

        define_method(name) do |*args|
          self.config.send("#{name}=", *args) if !args.empty?
          self.config.send(name)
        end

        define_method("#{name}=") do |new_value|
          self.config.send("#{name}=", new_value)
        end

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

      def service_handler_ns(value = nil)
        @service_handler_ns = value if value
        @service_handler_ns
      end

      def service(service_name, handler_class_name)
        if self.service_handler_ns && !(handler_class_name =~ /^::/)
          handler_class_name = "#{self.service_handler_ns}::#{handler_class_name}"
        end
        @services[service_name] = handler_class_name
      end

      def to_hash
        { self.name => self.services }
      end

    end

  end
end
