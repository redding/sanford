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

  class Manager

    def self.call(action, options = nil)
      self.new(options).tap{|manager| manager.send(action) }
    end

    attr_reader :host, :ip, :port, :process_name, :pid_file

    def initialize(opts = nil)
      options = OpenStruct.new(opts || {})
      host_name = ENV['SANFORD_HOST'] || options.host

      @host = host_name ? Sanford.hosts.find(host_name) : Sanford.hosts.first
      raise Sanford::NoHostError.new(host_name) if !@host

      @ip   = ENV['SANFORD_IP']   || options.ip   || @host.ip
      @port = ENV['SANFORD_PORT'] || options.port || @host.port
      raise Sanford::InvalidHostError.new(@host) if !@port
      @port = @port.to_i

      @process_name   = ProcessName.new(@host.name, @ip, @port)
      @server_options = {}
      # FUTURE allow passing through dat-tcp options (min/max workers)
      # FUTURE merge in host options for verbose / keep_alive

      options.pid_file ||= @host.pid_dir.join(@process_name).to_s
      @pid_file = PIDFile.new(options.pid_file)
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
      daemonize!(true) if daemonize
      puts "Starting Sanford server for #{@host.name} on #{@ip}:#{@port}"
      $0 = @process_name
      @pid_file.write

      Sanford::Server.new(@host, @server_options).tap do |server|
        server.listen(@ip, @port)

        Signal.trap("TERM"){ server.stop }
        Signal.trap("INT"){ server.halt(false) }

        server.run.join
      end
    ensure
      @pid_file.remove
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

    class ProcessName < String

      def initialize(name, ip, port)
        super "#{[ name, ip, port ].join('_')}.pid"
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

  class CLIRB  # Version 0.2.0, https://github.com/redding/cli.rb
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

end
