# The Manager class is responsible for managing sanford's server process. Given
# a host, it can start and stop the host's server process. This is done using
# the Daemons gem and `run_proc`. The class provides a convenience method on the
# class called `call`, which will find a host, build a new manager and call the
# relevant action (this is what the rake tasks use).
#
require 'daemons'

require 'sanford/hosts'
require 'sanford/server'

module Sanford

  class Manager
    attr_reader :host, :process_name

    def self.call(action, options = nil)
      options ||= {}
      registered_name = options.delete(:name) || ENV['SANFORD_NAME']
      options[:hostname] ||= ENV['SANFORD_HOSTNAME']
      options[:port] ||= ENV['SANFORD_PORT']

      host_class = registered_name ? Sanford::Hosts.find(registered_name) : Sanford::Hosts.first
      raise(Sanford::NoHost.new(registered_name)) if !host_class
      self.new(host_class, options).call(action)
    end

    def self.load_configuration
      begin
        require Sanford::Config.services_config
      rescue LoadError
        raise(Sanford::NoServicesConfigFile.new)
      end
    end

    def initialize(host_class, options = {})
      @host = host_class.new(options)
      @process_name = [ self.host.hostname, self.host.port, self.host.name ].join('_')
    end

    def call(action)
      options = self.default_options.merge({ :ARGV => [ action.to_s ] })
      ::Daemons.run_proc(self.process_name, options) do
        server = Sanford::Server.new(self.host)
        server.start
        server.join_thread
      end
    end

    protected

    def default_options
      { :dir_mode   => :normal,
        :dir        => self.host.pid_dir
      }
    end

  end

end
