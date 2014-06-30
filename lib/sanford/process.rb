require 'sanford/pid_file'

module Sanford

  class Process

    attr_reader :server, :name, :pid_file, :restart_cmd
    attr_reader :server_ip, :server_port, :server_fd, :client_fds

    def initialize(server, options = nil)
      options ||= {}
      @server = server
      @logger = @server.logger
      @name = "sanford-#{@server.name}"
      @pid_file = PIDFile.new(@server.pid_file)
      @restart_cmd = RestartCmd.new

      @server_ip = ignore_if_blank(ENV['SANFORD_IP'])
      @server_port = ignore_if_blank(ENV['SANFORD_PORT']){ |v| v.to_i }
      @server_fd = ignore_if_blank(ENV['SANFORD_SERVER_FD']){ |v| v.to_i }
      @listen_args = @server_fd ? [ @server_fd ] : [ @server_ip, @server_port ]
      @listen_args.compact!

      @client_fds = (ENV['SANFORD_CLIENT_FDS'] || "").split(',').map(&:to_i)

      @daemonize = !!options[:daemonize]
      @skip_daemonize = !!ignore_if_blank(ENV['SANFORD_SKIP_DAEMONIZE'])
    end

    def run
      ::Process.daemon(true) if self.daemonize?
      log "Starting Sanford server for #{@server.name}..."

      @server.listen(*@listen_args)
      log "Listening on #{@server.ip}:#{@server.port}"

      $0 = @name
      @pid_file.write
      log "PID: #{@pid_file.pid}"

      ::Signal.trap("TERM"){ @server.stop }
      ::Signal.trap("INT"){ @server.halt }
      ::Signal.trap("USR2"){ @server.pause }

      thread = @server.start(@client_fds)
      log "#{@server.name} server started and ready."
      thread.join
      exec_restart_cmd if @server.paused?
    rescue StandardError => exception
      log "Error: #{exception.message}"
      log "#{@server.name} server never started."
    ensure
      @pid_file.remove
    end

    def daemonize?
      @daemonize && !@skip_daemonize
    end

    private

    def log(message)
      @logger.info "[Sanford] #{message}"
    end

    def exec_restart_cmd
      log "Restarting #{@server.name} daemon..."
      ENV['SANFORD_SERVER_FD'] = @server.file_descriptor.to_s
      ENV['SANFORD_CLIENT_FDS'] = @server.client_file_descriptors.join(',')
      ENV['SANFORD_SKIP_DAEMONIZE'] = 'yes'
      @restart_cmd.exec
    end

    def ignore_if_blank(value, default = nil, &block)
      block ||= proc{ |v| v }
      value && !value.empty? ? block.call(value) : default
    end

  end

  class RestartCmd
    attr_reader :argv, :dir

    def initialize
      require 'rubygems'
      @dir  = get_pwd
      @argv = [ Gem.ruby, $0, ARGV.dup ].flatten
    end

    def exec
      Dir.chdir self.dir
      Kernel.exec(*self.argv)
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

  # This is from puma for 1.8 compatibility. Ruby 1.9+ defines a
  # `Process.daemon` for daemonizing processes. This defines the method when it
  # isn't provided, i.e. Ruby 1.8.
  unless ::Process.respond_to?(:daemon)
    ::Process.class_eval do

      # Full explanation: http://www.steve.org.uk/Reference/Unix/faq_2.html#SEC16
      def self.daemon(no_chdir = false, no_close = false)
        exit if fork
        ::Process.setsid
        exit if fork
        Dir.chdir '/' unless no_chdir
        if !no_close
          null = File.open('/dev/null', 'w')
          STDIN.reopen null
          STDOUT.reopen null
          STDERR.reopen null
        end
        return 0
      end

    end
  end

end
