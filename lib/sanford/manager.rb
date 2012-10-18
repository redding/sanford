# The Manager class is responsible for managing sanford's server process. It
# uses the daemons gem to do this. Given a host and optional process name,
# the manager can start or stop the host. Daemons' `run_proc` method is used
# along with the action (start, stop, run, restart) to provide this
# functionality. The Manager's provides a class method `call` for convenience,
# primarily used by the rake tasks. They allow passing a host name which will
# look up a host from it (see Sanford::Hosts). The host is then used to
# create an instance of a Manager, then the action is called on the manager.
#
require 'daemons'

require 'sanford/hosts'
require 'sanford/server'

module Sanford

  class Manager
    attr_reader :host, :process_name

    def self.call(host_name, action)
      host = host_name ? Sanford::Hosts.find(host_name) : Sanford::Hosts.first
      raise(Sanford::NoServiceHost.new(host_name)) if !host
      self.new(host).call(action)
    end

    def self.load_configuration
      begin
        require Sanford::Config.services_config
      rescue LoadError
        raise(Sanford::NoServicesConfigFile.new)
      end
    end

    def initialize(host)
      @host = host
      @process_name = host.name
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
        :dir        => self.host.config.pid_dir
      }
    end

  end

end
