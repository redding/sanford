require 'ns-options'

require 'sanford/exceptions'
require 'sanford/host_configuration'
require 'sanford/host_version_group'
require 'sanford/service_handler'

module Sanford

  module Host

    def self.included(host_class)
      host_class.class_eval do
        extend Sanford::Host::Interface
      end
      Sanford.register(host_class)
    end

    attr_reader :config

    # The `initialize` takes the values configured on the class and merges
    # the passed in options. This is used to set the individual instance's
    # configuration (which allows overwriting options like the port).
    def initialize(options = nil)
      options = NsOptions::Struct.new(self.remove_nil_values(options))
      @config = Sanford::HostConfiguration.new(self, self.class.config)
      @config.apply(options.to_hash)

      raise(Sanford::InvalidHostError.new(self.class)) if !self.port
    end

    # define convenience accessors for configuration options
    [ :name, :ip, :port, :pid_dir, :logger, :verbose_logging, :exception_handler ].each do |name|

      define_method(name) do
        self.config.send(name)
      end

    end

    def handler_class_for(version, name)
      Sanford::ServiceHandler.constantize(handler_class_name(version, name)).tap do |handler_class|
        raise Sanford::NoHandlerClassError.new(self, class_name_str) if !handler_class
      end
    end

    def inspect
      reference = '0x0%x' % (self.object_id << 1)
      "#<#{self.class}:#{reference} ip=#{self.config.ip.inspect} " \
      "port=#{self.config.port.inspect}>"
    end

    protected

    def handler_class_name(version, name)
      services = self.config.versioned_services[version] || {}
      services[name].tap do |name|
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

      def config
        @config ||= Sanford::HostConfiguration.new(self)
      end

      # Define convenience methods for setting configuration options from the
      # Host class. Allows setting port with `port 8000`.
      [ :name, :ip, :port, :pid_dir, :logger, :verbose_logging, :exception_handler ].each do |name|

        define_method(name) do |*args|
          self.config.send("#{name}=", *args) if !args.empty?
          self.config.send(name)
        end

        define_method("#{name}=") do |new_value|
          self.config.send("#{name}=", new_value)
        end

      end

      def version(name, &block)
        version_group = Sanford::HostVersionGroup.new(name, &block)
        self.config.versioned_services.merge!(version_group.to_hash)
      end

    end

  end

end
