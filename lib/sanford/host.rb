require 'ns-options'
require 'pathname'

require 'sanford/exceptions'
require 'sanford/logger'

module Sanford

  module Host

    class Configuration
      include NsOptions::Proxy

      # A Host's configuration is a seperate ns-options proxy class because
      # `Host` is a module, so it itself cannot be a ns-options proxy (and
      # still function as a mixin). Also, since it is making the `Host`
      # a `Singleton`, mixing that with `NsOptions::Proxy` could have strange
      # effects (messing up someone's `initialize`). Thus, the `Configuration`
      # is a separate class and not on the `Host` directly.

      option :name,                 String
      option :ip,                   String,   :default => '0.0.0.0'
      option :port,                 Integer
      option :pid_dir,              Pathname, :default => Dir.pwd
      option :logger,                         :default => proc{ Sanford::NullLogger.new }
      option :verbose_logging,                :default => true
      option :receives_keep_alive,            :default => false
      option :error_proc,           Proc,     :default => proc{ }
      option :setup_proc,           Proc,     :default => proc{ }

      def initialize(host)
        self.name = host.class.to_s
      end

    end

    def self.included(host_class)
      host_class.class_eval do
        include Singleton
        extend Sanford::Host::ClassMethods
      end
      Sanford.register(host_class)
    end

    attr_reader :configuration, :versioned_services

    def initialize
      @configuration = Configuration.new(self)
      @versioned_services = {}
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

    def pid_dir(*args)
      self.configuration.pid_dir *args
    end

    def logger(*args)
      self.configuration.logger *args
    end

    def verbose_logging(*args)
      self.configuration.verbose_logging *args
    end

    def receives_keep_alive(*args)
      self.configuration.receives_keep_alive *args
    end

    def error(&block)
      self.configuration.error_proc = block
    end

    def setup(&block)
      self.configuration.setup_proc = block
    end

    def version(name, &block)
      version_group = Sanford::Host::VersionGroup.new(name, &block)
      @versioned_services.merge!(version_group.to_hash)
    end

    def inspect
      reference = '0x0%x' % (self.object_id << 1)
      "#<#{self.class}:#{reference} ip=#{self.configuration.ip.inspect} " \
      "port=#{self.configuration.port.inspect}>"
    end

    protected

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

    module ClassMethods

      # the class level of a `Host` should just proxy it's methods down to it's
      # instance (it's a `Singleton`)

      # `name` is defined by all objects, so we can't rely on `method_missing`
      def name(*args)
        self.instance.name(*args)
      end

      def method_missing(method, *args, &block)
        self.instance.send(method, *args, &block)
      end

      def respond_to?(method)
        super || self.instance.respond_to?(method)
      end

    end

  end

end
