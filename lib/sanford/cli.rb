require 'sanford'
require 'sanford/host_data'
require 'sanford/server'
require 'sanford/version'

module Sanford

  class CLI

    def self.run(*args)
      self.new.run(*args)
    end

    def initialize
      @cli = CLIRB.new do
        option :host,   "Name of the Host configuration",     :value => String
        option :ip,     "IP address to bind to",              :value => String
        option :port,   "Port number to bind to",             :value => Integer
        option :config, "File defining the configured Hosts", :value => String
      end
    end

    def run(*args)
      begin
        @cli.parse!(*args)
        @command = @cli.args.first || 'run'
        Sanford.config.services_file = @cli.opts['config'] if @cli.opts['config']
        Sanford.init
        Sanford::Manager.call(@command, @cli.opts)
      rescue CLIRB::HelpExit
        puts help
      rescue CLIRB::VersionExit
        puts Sanford::VERSION
      rescue CLIRB::Error => exception
        puts "#{exception.message}\n\n"
        puts help
        exit(1)
      rescue SystemExit
      rescue Exception => exception
        puts "#{exception.class}: #{exception.message}"
        puts exception.backtrace.join("\n") if ENV['DEBUG']
        exit(1)
      end
      exit(0)
    end

    def help
      "Usage: sanford <command> <options> \n" \
      "Commands: run, start, stop, restart \n" \
      "#{@cli}"
    end

  end

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
        self.run!
      end

      def start
        self.run! true
      end

      protected

      def run!(daemonize = false)
        daemonize!(true) if daemonize
        Sanford::Server.new(@host, @server_options).tap do |server|
          @logger.info "Starting Sanford server for #{@host.name}"

          server.listen(*@config.listen_args)
          @logger.info "Listening on #{server.ip}:#{server.port}"
          @logger.info "PID: #{Process.pid}"

          $0 = ProcessName.new(@host, server.ip, server.port)
          @config.pid_file.write

          Signal.trap("TERM"){ self.stop!(server) }
          Signal.trap("INT"){  self.halt!(server) }
          Signal.trap("USR2"){ self.restart!(server) }

          server.run(@config.client_file_descriptors).join
        end
      ensure
        @config.pid_file.remove
      end

      def restart!(server)
        @logger.info "Restarting the server..."
        server.pause
        @logger.info "server paused"

        ENV['SANFORD_HOST']        = @host.name
        ENV['SANFORD_SERVER_FD']   = server.file_descriptor.to_s
        ENV['SANFORD_CLIENT_FDS']  = server.client_file_descriptors.join(',')

        @logger.info "calling exec ..."
        Dir.chdir @restart_cmd.dir
        Kernel.exec(*@restart_cmd.argv)
      end

      def stop!(server)
        @logger.info "Stopping the server..."
        server.stop
        @logger.info "Done"
      end

      def halt!(server)
        @logger.info "Halting the server..."
        server.halt false
        @logger.info "Done"
      end

      def daemonize!(no_chdir = false, no_close = false)
        exit if fork                     # Parent exits, child continues.
        Process.setsid                   # Become session leader.
        exit if fork                     # Zap session leader. See [1].
        Dir.chdir "/" unless no_chdir    # Release old working directory.
        if !no_close
          null = File.open "/dev/null", 'w'
          STDIN.reopen null
          STDOUT.reopen null
          STDERR.reopen null
        end
        0
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

    class Config
      attr_reader :host_name, :host, :ip, :port, :file_descriptor
      attr_reader :client_file_descriptors, :pid_file, :pid, :restart_dir

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

    end

    class NullHost
      [ :ip, :port, :pid_file ].each do |method_name|
        define_method(method_name){ }
      end
    end

    class ProcessName < String
      def initialize(name, ip, port)
        super "#{[ name, ip, port ].join('_')}"
      end
    end

    class PIDFile
      def initialize(path)
        @path = (path || '/dev/null').to_s
      end

      def pid
        pid = File.read(@path).strip if File.exists?(@path)
        pid.to_i if pid && !pid.empty?
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
      # symlink, useful for when the pwd is /data/releases/current.
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

  class CLIRB  # Version 1.0.0, https://github.com/redding/cli.rb
    Error    = Class.new(RuntimeError);
    HelpExit = Class.new(RuntimeError); VersionExit = Class.new(RuntimeError)
    attr_reader :argv, :args, :opts, :data

    def initialize(&block)
      @options = []; instance_eval(&block) if block
      require 'optparse'
      @data, @args, @opts = [], [], {}; @parser = OptionParser.new do |p|
        p.banner = ''; @options.each do |o|
          @opts[o.name] = o.value; p.on(*o.parser_args){ |v| @opts[o.name] = v }
        end
        p.on_tail('--version', ''){ |v| raise VersionExit, v.to_s }
        p.on_tail('--help',    ''){ |v| raise HelpExit,    v.to_s }
      end
    end

    def option(*args); @options << Option.new(*args); end
    def parse!(argv)
      @args = (argv || []).dup.tap do |args_list|
        begin; @parser.parse!(args_list)
        rescue OptionParser::ParseError => err; raise Error, err.message; end
      end; @data = @args + [@opts]
    end
    def to_s; @parser.to_s; end
    def inspect
      "#<#{self.class}:#{'0x0%x' % (object_id << 1)} @data=#{@data.inspect}>"
    end

    class Option
      attr_reader :name, :opt_name, :desc, :abbrev, :value, :klass, :parser_args

      def initialize(name, *args)
        settings, @desc = args.last.kind_of?(::Hash) ? args.pop : {}, args.pop || ''
        @name, @opt_name, @abbrev = parse_name_values(name, settings[:abbrev])
        @value, @klass = gvalinfo(settings[:value])
        @parser_args = if [TrueClass, FalseClass, NilClass].include?(@klass)
          ["-#{@abbrev}", "--[no-]#{@opt_name}", @desc]
        else
          ["-#{@abbrev}", "--#{@opt_name} #{@opt_name.upcase}", @klass, @desc]
        end
      end

      private

      def parse_name_values(name, custom_abbrev)
        [ (processed_name = name.to_s.strip.downcase), processed_name.gsub('_', '-'),
          custom_abbrev || processed_name.gsub(/[^a-z]/, '').chars.first || 'a'
        ]
      end
      def gvalinfo(v); v.kind_of?(Class) ? [nil,gklass(v)] : [v,gklass(v.class)]; end
      def gklass(k); k == Fixnum ? Integer : k; end
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
