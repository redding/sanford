require 'daemons'

require 'sanford/host_data'
require 'sanford/server'

module Sanford

  class Manager

    def self.call(action, options = nil)
      options ||= {}
      options[:ip]    ||= ENV['SANFORD_IP']
      options[:port]  ||= ENV['SANFORD_PORT']

      name = options.delete(:host) || ENV['SANFORD_HOST']
      service_host = name ? Sanford.hosts.find(name) : Sanford.hosts.first
      raise(Sanford::NoHostError.new(name)) if !service_host

      self.new(service_host, options).call(action)
    end

    attr_reader :host, :process_name

    def initialize(service_host, options = {})
      @host = Sanford::HostData.new(service_host, options)
      @process_name = [ self.host.ip, self.host.port, self.host.name ].join('_')
    end

    def call(action)
      daemons_options = self.default_options.merge({ :ARGV => [ action.to_s ] })
      FileUtils.mkdir_p(daemons_options[:dir])
      ::Daemons.run_proc(self.process_name, daemons_options) do
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
