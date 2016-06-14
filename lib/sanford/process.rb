require 'sanford/io_pipe'
require 'sanford/pid_file'

module Sanford

  class Process

    HALT    = 'H'.freeze
    STOP    = 'S'.freeze
    RESTART = 'R'.freeze

    WAIT_FOR_SIGNALS_TIMEOUT = 15

    attr_reader :server, :name, :pid_file, :signal_io, :restart_cmd
    attr_reader :server_ip, :server_port, :server_fd, :client_fds

    def initialize(server, options = nil)
      options ||= {}
      @server = server
      @name   = "sanford: #{@server.process_label}"
      @logger = @server.logger

      @pid_file    = PIDFile.new(@server.pid_file)
      @signal_io   = IOPipe.new
      @restart_cmd = RestartCmd.new

      @server_ip   = @server.configured_ip
      @server_port = @server.configured_port
      @server_fd   = if !ENV['SANFORD_SERVER_FD'].to_s.empty?
        ENV['SANFORD_SERVER_FD'].to_i
      end
      @listen_args = @server_fd ? [@server_fd] : [@server_ip, @server_port]

      @client_fds = ENV['SANFORD_CLIENT_FDS'].to_s.split(',').map(&:to_i)

      skip_daemonize = ignore_if_blank(ENV['SANFORD_SKIP_DAEMONIZE'])
      @daemonize = !!options[:daemonize] && !skip_daemonize
    end

    def run
      ::Process.daemon(true) if self.daemonize?
      log "Starting Sanford server for #{@server.name}..."

      @server.listen(*@listen_args)
      log "Listening on #{@server.ip}:#{@server.port}"

      $0 = @name
      @pid_file.write
      log "PID: #{@pid_file.pid}"

      @signal_io.setup
      trap_signals(@signal_io)

      start_server(@server, @client_fds)

      signal = catch(:signal) do
        wait_for_signals(@signal_io, @server)
      end
      @signal_io.teardown

      run_restart_cmd(@restart_cmd, @server) if signal == RESTART
    ensure
      @pid_file.remove
    end

    def daemonize?; @daemonize; end

    private

    def start_server(server, client_fds)
      server.start(client_fds)
      log "#{server.name} server started and ready."
    rescue StandardError => exception
      log "#{server.name} server never started."
      raise exception
    end

    def trap_signals(signal_io)
      trap_signal('INT'){  signal_io.write(HALT) }
      trap_signal('TERM'){ signal_io.write(STOP) }
      trap_signal('USR2'){ signal_io.write(RESTART) }
    end

    def trap_signal(signal, &block)
      ::Signal.trap(signal, &block)
    rescue ArgumentError
      log "'#{signal}' signal not supported"
    end

    def wait_for_signals(signal_io, server)
      loop do
        ready = signal_io.wait(WAIT_FOR_SIGNALS_TIMEOUT)
        handle_signal(signal_io.read, server) if ready

        if !server.running?
          log "Server crashed, restarting"
          start_server(server, server.client_file_descriptors)
        end
      end
    end

    def handle_signal(signal, server)
      log "Got '#{signal}' signal"
      case signal
      when HALT
        server.halt(true)
      when STOP
        server.stop(true)
      when RESTART
        server.pause(true)
      end
      throw :signal, signal
    end

    def run_restart_cmd(restart_cmd, server)
      log "Restarting #{server.name} daemon..."
      restart_cmd.run(server)
    end

    def log(message)
      @logger.info "[Sanford] #{message}"
    end

    def ignore_if_blank(value, &block)
      block ||= proc{ |v| v }
      block.call(value) if value && !value.empty?
    end

  end

  class RestartCmd
    attr_reader :argv, :dir

    def initialize
      require 'rubygems'
      @dir  = get_pwd
      @argv = [Gem.ruby, $0, ARGV.dup].flatten
    end

    if RUBY_VERSION == '1.8.7'

      def run(server)
        ENV['SANFORD_SERVER_FD']      = server.file_descriptor.to_s
        ENV['SANFORD_CLIENT_FDS']     = server.client_file_descriptors.join(',')
        ENV['SANFORD_SKIP_DAEMONIZE'] = 'yes'
        Dir.chdir self.dir
        Kernel.exec(*self.argv)
      end

    else

      def run(server)
        env = {
          'SANFORD_SERVER_FD'      => server.file_descriptor.to_s,
          'SANFORD_CLIENT_FDS'     => server.client_file_descriptors.join(','),
          'SANFORD_SKIP_DAEMONIZE' => 'yes'
        }
        # in ruby 1.9+ the `Kernel.exec` method is passed file descriptor
        # redirects, this makes it so the child process that we are running via
        # the `exec` has access to the file descriptors and can open them
        fd_redirects = (
          [server.file_descriptor] +
          server.client_file_descriptors
        ).inject({}){ |h, fd| h.merge!(fd => fd) }
        options = { :chdir => self.dir }.merge!(fd_redirects)

        Kernel.exec(*([env] + self.argv + [options]))
      end

    end

    private

    # Trick from puma/unicorn. Favor PWD because it contains an unresolved
    # symlink. This is useful when restarting after deploying; the original
    # directory may be removed, but the symlink is pointing to a new
    # directory.
    def get_pwd
      return Dir.pwd if ENV['PWD'].nil?
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
