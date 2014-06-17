require 'sanford/cli'
require 'sanford/server_old'

module Sanford

  module Manager

    def self.call(action, options = nil)
      get_handler_class(action).new(options).tap{ |manager| manager.send(action) }
    end

    def self.get_handler_class(action)
      case action.to_sym
      when :start, :run
        ServerHandler
      when :stop, :restart
        SignalHandler
      end
    end

    class Config
      attr_reader :host_name, :host, :ip, :port, :pid, :pid_file, :restart_dir
      attr_reader :file_descriptor, :client_file_descriptors

      def initialize(opts = nil)
        options = OpenStruct.new(opts || {})
        @host_name = ENV['SANFORD_HOST'] || options.host

        @host = @host_name ? Sanford.hosts.find(@host_name) : Sanford.hosts.first
        @host ||= NullHost.new

        @file_descriptor = ENV['SANFORD_SERVER_FD'] || options.file_descriptor
        @file_descriptor = @file_descriptor.to_i if @file_descriptor
        @ip   = ENV['SANFORD_IP']   || options.ip   || @host.ip
        @port = ENV['SANFORD_PORT'] || options.port || @host.port
        @port = @port.to_i if @port

        client_fds_str = ENV['SANFORD_CLIENT_FDS'] || options.client_fds || ""
        @client_file_descriptors = client_fds_str.split(',').map(&:to_i)

        @pid_file = PIDFile.new(ENV['SANFORD_PID_FILE'] || options.pid_file || @host.pid_file)
        @pid      = options.pid || @pid_file.pid

        @restart_dir = ENV['SANFORD_RESTART_DIR'] || options.restart_dir
      end

      def listen_args
        @file_descriptor ? [ @file_descriptor ] : [ @ip, @port ]
      end

      def has_listen_args?
        !!@file_descriptor || !!(@ip && @port)
      end

      def found_host?
        !@host.kind_of?(NullHost)
      end

      class NullHost
        [ :ip, :port, :pid_file ].each do |method_name|
          define_method(method_name){ }
        end
      end

      class PIDFile
        DEF_FILE = '/dev/null'

        def initialize(path)
          @path = (path || DEF_FILE).to_s
        end

        def pid
          pid = File.read(@path).strip if File.exists?(@path)
          pid.to_i if pid && !pid.empty?
        end

        def write
          begin
            File.open(@path, 'w'){|f| f.puts Process.pid }
          rescue Errno::ENOENT => err
            e = RuntimeError.new("Can't write pid to file `#{@path}`")
            e.set_backtrace(err.backtrace)
            raise e
          end
        end

        def remove
          FileUtils.rm_f(@path)
        end

        def to_s
          @path
        end
      end

    end

    class ServerHandler

      def initialize(options = nil)
        @config = Config.new(options)
        raise Sanford::NoHostError.new(@config.host_name) if !@config.found_host?
        raise Sanford::InvalidHostError.new(@config.host) if !@config.has_listen_args?
        @host   = @config.host
        @logger = @host.logger

        @server_options = {}
        # FUTURE allow passing through dat-tcp options (min/max workers)
        # FUTURE merge in host options for verbose / keep_alive

        @restart_cmd = RestartCmd.new(@config)
      end

      def run
        self.run! false
      end

      def start
        self.run! true
      end

      protected

      def run!(daemonize = false)
        daemonize!(true) if daemonize && !ENV['SANFORD_SKIP_DAEMONIZE']
        Sanford::ServerOld.new(@host, @server_options).tap do |server|
          log "Starting #{@host.name} server..."

          server.listen(*@config.listen_args)
          $0 = ProcessName.new(@host.name, server.ip, server.port)
          log "Listening on #{server.ip}:#{server.port}"

          @config.pid_file.write
          log "PID: #{Process.pid}"

          Signal.trap("TERM"){ self.stop!(server) }
          Signal.trap("INT"){  self.halt!(server) }
          Signal.trap("USR2"){ self.restart!(server) }

          server_thread = server.start(@config.client_file_descriptors)
          log "#{@host.name} server started and ready."
          server_thread.join
        end
      rescue RuntimeError => err
        log "Error: #{err.message}"
        log "#{@host.name} server never started."
      ensure
        @config.pid_file.remove
      end

      def restart!(server)
        log "Restarting #{@host.name} server..."
        server.pause
        log "server paused"

        ENV['SANFORD_HOST']           = @host.name
        ENV['SANFORD_SERVER_FD']      = server.file_descriptor.to_s
        ENV['SANFORD_CLIENT_FDS']     = server.client_file_descriptors.join(',')
        ENV['SANFORD_SKIP_DAEMONIZE'] = 'yes'

        log "calling exec ..."
        Dir.chdir @restart_cmd.dir
        Kernel.exec(*@restart_cmd.argv)
      end

      def stop!(server)
        log "Stopping #{@host.name} server..."
        server.stop
        log "#{@host.name} server stopped."
      end

      def halt!(server)
        log "Halting #{@host.name} server..."
        server.halt false
        log "#{@host.name} server halted."
      end

      # Full explanation: http://www.steve.org.uk/Reference/Unix/faq_2.html#SEC16
      def daemonize!(no_chdir = false, no_close = false)
        exit if fork
        Process.setsid
        exit if fork
        Dir.chdir "/" unless no_chdir
        if !no_close
          null = File.open "/dev/null", 'w'
          STDIN.reopen null
          STDOUT.reopen null
          STDERR.reopen null
        end
        return 0
      end

      def log(message)
        @logger.info "[Sanford] #{message}"
      end

      class ProcessName < String
        def initialize(name, ip, port)
          super "#{[ name, ip, port ].join('_')}"
        end
      end

      class RestartCmd
        attr_reader :argv, :dir

        def initialize(config = nil)
          require 'rubygems'
          config ||= OpenStruct.new
          @dir = config.restart_dir || get_pwd
          @argv = [ Gem.ruby, $0, ARGV.dup ].flatten
        end

        protected

        # Trick from puma/unicorn. Favor PWD because it contains an unresolved
        # symlink. This is useful when restarting after deploying; the original
        # directory may be removed, but the symlink is pointing to a new
        # directory.
        def get_pwd
          env_stat = File.stat(ENV['PWD'])
          pwd_stat = File.stat(Dir.pwd)
          if env_stat.ino == pwd_stat.ino && env_stat.dev == pwd_stat.dev
            ENV['PWD']
          else
            Dir.pwd
          end
        end

      end

    end

    class SignalHandler

      def initialize(options = nil)
        @config = Config.new(options)
        raise Sanford::NoPIDError.new if !@config.pid
      end

      def stop
        Process.kill("TERM", @config.pid)
      end

      def restart
        Process.kill("USR2", @config.pid)
      end

    end

  end

  class NoHostError < CLIRB::Error
    def initialize(host_name)
      message = if Sanford.hosts.empty?
        "No hosts have been defined. Please define a host before trying to run Sanford."
      else
        "A host couldn't be found with the name #{host_name.inspect}. "
      end
      super message
    end
  end

  class InvalidHostError < CLIRB::Error
    def initialize(host)
      super "A port must be configured or provided to run a server for '#{host}'"
    end
  end

  class NoPIDError < CLIRB::Error
    def initialize
      super "A PID or PID file is required"
    end
  end

end
