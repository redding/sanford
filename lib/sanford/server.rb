require 'ns-options'
require 'ns-options/boolean'
require 'sanford/logger'
require 'sanford/router'
require 'sanford/template_source'

module Sanford

  module Server

    def self.included(klass)
      klass.class_eval do
        extend ClassMethods
        include InstanceMethods
      end
    end

    module InstanceMethods

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

      def router(value = nil)
        self.configuration.router = value if !value.nil?
        self.configuration.router
      end

      def set_template_source(path, &block)
        self.configuration.set_template_source(path, &block)
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

end
