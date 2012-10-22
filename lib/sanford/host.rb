# Sanford's Host mixin is used to define service hosts. When mixed into a class
# it provides the interface for defnining the service host. A service host can
# be given a name and has a number of options that can be set using it's
# `configure` method. These options modify how to connect to the service host
# (hostname and port) and how the service host process runs (pid_dir and
# logging).
#
# TODO - incomplete until service interface is added
#
# Options:
# * `hostname`  - The string for the hostname that the TCP Server should bind
#                 to. This defaults to '127.0.0.1'.
# * `port`      - The integer for the port that the TCP Server should bind to.
#                 This isn't defaulted and must be provided.
# * `pid_dir`   - The directory to write the PID file to. This is defaulted to
#                 Dir.pwd.
# * `logging`   - Boolean for whether or not the Sanford server should log.
#                 Defaults to true.
# * `logger`    - The logger to use if the Sanford server logs messages. This is
#                 defaulted to an instance of Ruby's Logger.
#
require 'singleton'
require 'logger'
require 'ns-options'
require 'pathname'

require 'sanford/hosts'

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
          option :hostname, String,   :default => '127.0.0.1'
          option :port,     Integer
          option :pid_dir,  Pathname, :default => Dir.pwd
          option :logging,            :default => true
          option :logger,             :default => nil
        end
      end
      Sanford::Hosts.add(host_class)
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

    def method_missing(method, *args, &block)
      self.config.send(method, *args, &block)
    end

    def respond_to?(method)
      super || self.config.respond_to?(method)
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

    end

  end

end
