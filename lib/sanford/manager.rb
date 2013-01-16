require 'daemons'

require 'sanford/exceptions'
require 'sanford/server'

module Sanford

  class Manager
    attr_reader :host, :process_name

    def self.call(action, options = nil)
      options ||= {}
      options[:host]  ||= ENV['SANFORD_HOST']
      options[:ip]    ||= ENV['SANFORD_IP']
      options[:port]  ||= ENV['SANFORD_PORT']

      host_class = if (host_class_or_name = options.delete(:host))
        Sanford.hosts.find(host_class_or_name)
      else
        Sanford.hosts.first
      end
      raise(Sanford::NoHostError.new(host_class_or_name)) if !host_class
      self.new(host_class, options).call(action)
    end

    def initialize(host_class, options = {})
      @host = host_class.new(options)
      @process_name = [ self.host.ip, self.host.port, self.host.name ].join('_')
    end

    def call(action)
      options = self.default_options.merge({ :ARGV => [ action.to_s ] })
      FileUtils.mkdir_p(options[:dir])
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
