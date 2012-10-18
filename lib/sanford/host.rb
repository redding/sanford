# Sanford's Host mixin is used to define service hosts. When mixed into a class
# it converts it to a singleton and provides the interface for defnining the
# the service host. A service host can be given a name and has a number of
# options that can be set using it's `configure` method. These options modify
# how to connect to the service host (hostname and port) and how the service
# host process runs (pid_dir and logging).
#
# TODO - incomplete until service interface is added
#
# Options:
# * `host`    - The string for the hostname that the TCP Server should bind to.
#               This defaults to '127.0.0.1'.
# * `port`    - The integer for the port that the TCP Server should bind to.
#               This isn't defaulted and must be provided.
# * `pid_dir` - The directory to write the PID file to. This is defaulted to
#               Dir.pwd.
# * `logging` - Boolean for whether or not the Sanford server should log.
#               Defaults to true.
# * `logger`  - The logger to use if the Sanford server logs messages. This is
#               defaulted to an instance of Ruby's Logger.
#
require 'singleton'
require 'logger'
require 'ns-options'
require 'pathname'

require 'sanford/hosts'

module Sanford

  module Host

    def self.included(host_class)
      host_class.class_eval do
        include Singleton
        extend Sanford::Host::ClassMethods
      end
      Sanford::Hosts.add(host_class)
    end

    attr_reader :config

    def initialize
      @name = self.class.host_name_for(self.class)
      @config = Sanford::Host::Configuration.new
    end

    def name(value = nil)
      @name = value if value
      @name
    end

    def configure(&block)
      self.config.define(&block)
    end

    module ClassMethods

      # `name` is defined by all classes so `method_missing` won't work
      def name(*args)
        self.instance.name(*args)
      end

      def method_missing(method, *args, &block)
        self.instance.send(method, *args, &block)
      end

      def respond_to?(method)
        super || self.instance.respond_to?(method)
      end

      def host_name_for(host_class)
        class_name = host_class.to_s.split('::').last
        class_name.gsub(/([a-z\d])([A-Z])/,'\1_\2').downcase
      end

    end

    class Configuration
      include NsOptions::Proxy

      option :host,     String,   :default => '127.0.0.1'
      option :port,     Integer
      option :pid_dir,  Pathname, :default => Dir.pwd
      option :logging,            :default => true
      option :logger,             :default => nil

      def bind(address)
        self.host, self.port = address.split(":")
      end
    end

  end

end
