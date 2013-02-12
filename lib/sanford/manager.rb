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

      self.new(service_host, options).send(action)
    end

    attr_reader :process_name

    def initialize(service_host, options = {})
      @service_host, @host_options = service_host, options
      @pid_dir      = @service_host.pid_dir || @host_options[:pid_dir]
      @process_name = ProcessName.new(@service_host, @host_options)

      @pid_file = PIDFile.new("#{@pid_dir.join(@process_name)}.pid")
    end

    def run
      self.run!
    end

    def start
      self.run! true
    end

    def stop
      Process.kill("TERM", @pid_file.pid)
    end

    def restart
      raise NotImplementedError # TODO
    end

    protected

    def run!(daemonize = false)
      puts "Starting Sanford server for #{@service_host.name} on #{@process_name.uri}"
      daemonize!(true) if daemonize
      $0 = @process_name
      @pid_file.write

      server = Sanford::Server.new(@service_host, @host_options)
      server.connect

      Signal.trap("TERM"){ server.stop }

      server.start
      server.join_thread
    ensure
      @pid_file.remove
    end

    def daemonize!(no_chdir = false, no_close = false)
      exit if fork                     # Parent exits, child continues.
      Process.setsid                   # Become session leader.
      exit if fork                     # Zap session leader. See [1].
      Dir.chdir "/" unless no_chdir    # Release old working directory.
      if !no_close
        null = File.open "/dev/null"
        STDIN.reopen null
        STDOUT.reopen null
        STDERR.reopen null
      end
      0
    end

    class ProcessName < String
      attr_reader :ip, :port

      def initialize(host, options)
        @ip    = options[:ip] || host.ip
        @port  = options[:port] || host.port
        super [ @ip, @port, host.name ].join('_')
      end

      def uri
        "#{ip}:#{port}"
      end

    end

    class PIDFile

      def initialize(path)
        @path = path
      end

      def pid
        pid = File.read(@path).strip
        pid.to_i if pid
      end

      def write
        File.open(@path, 'w'){|f| f.puts Process.pid }
      end

      def remove
        FileUtils.rm_f(@path)
      end

      def to_s
        @path
      end

    end

  end

end
