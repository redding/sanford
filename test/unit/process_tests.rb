require 'assert'
require 'sanford/process'

require 'sanford/server'
require 'test/support/pid_file_spy'

class Sanford::Process

  class UnitTests < Assert::Context
    desc "Sanford::Process"
    setup do
      @process_class = Sanford::Process
    end
    subject{ @process_class }

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @current_env_server_fd      = ENV['SANFORD_SERVER_FD']
      @current_env_client_fds     = ENV['SANFORD_CLIENT_FDS']
      @current_env_skip_daemonize = ENV['SANFORD_SKIP_DAEMONIZE']
      ENV.delete('SANFORD_SERVER_FD')
      ENV.delete('SANFORD_CLIENT_FDS')
      ENV.delete('SANFORD_SKIP_DAEMONIZE')

      @server_spy = ServerSpy.new

      @pid_file_spy = PIDFileSpy.new(Factory.integer)
      Assert.stub(Sanford::PIDFile, :new).with(@server_spy.pid_file) do
        @pid_file_spy
      end

      @restart_cmd_spy = RestartCmdSpy.new
      Assert.stub(Sanford::RestartCmd, :new){ @restart_cmd_spy }

      @process = @process_class.new(@server_spy)
    end
    teardown do
      ENV['SANFORD_SKIP_DAEMONIZE'] = @current_env_skip_daemonize
      ENV['SANFORD_CLIENT_FDS']     = @current_env_client_fds
      ENV['SANFORD_SERVER_FD']      = @current_env_server_fd
    end
    subject{ @process }

    should have_readers :server, :name, :pid_file, :restart_cmd
    should have_readers :server_ip, :server_port, :server_fd, :client_fds
    should have_imeths :run, :daemonize?

    should "know its server" do
      assert_equal @server_spy, subject.server
    end

    should "know its name, pid file and restart cmd" do
      expected = "sanford-#{@server_spy.name}-" \
                 "#{@server_spy.configured_ip}-#{@server_spy.configured_port}"
      assert_equal expected, subject.name
      assert_equal @pid_file_spy, subject.pid_file
      assert_equal @restart_cmd_spy, subject.restart_cmd
    end

    should "know its server ip, port and file descriptor" do
      assert_equal @server_spy.configured_ip, subject.server_ip
      assert_equal @server_spy.configured_port, subject.server_port
      assert_nil subject.server_fd
    end

    should "allow overriding its file descriptor using an env var" do
      ENV['SANFORD_SERVER_FD'] = Factory.integer.to_s
      process = @process_class.new(@server_spy)
      assert_equal ENV['SANFORD_SERVER_FD'].to_i, process.server_fd

      ENV['SANFORD_SERVER_FD'] = ''
      process = @process_class.new(@server_spy)
      assert_nil process.server_fd

      ENV.delete('SANFORD_SERVER_FD')
      process = @process_class.new(@server_spy)
      assert_nil process.server_fd
    end

    should "know its client file descriptors" do
      assert_equal [], subject.client_fds
    end

    should "set its client file descriptors using an env var" do
      client_fds = [Factory.integer, Factory.integer]
      ENV['SANFORD_CLIENT_FDS'] = client_fds.join(',')
      process = @process_class.new(@server_spy)
      assert_equal client_fds, process.client_fds
    end

    should "not daemonize by default" do
      process = @process_class.new(@server_spy)
      assert_false process.daemonize?
    end

    should "daemonize if turned on" do
      process = @process_class.new(@server_spy, :daemonize => true)
      assert_true process.daemonize?
    end

    should "not daemonize if skipped via the env var" do
      ENV['SANFORD_SKIP_DAEMONIZE'] = 'yes'
      process = @process_class.new(@server_spy)
      assert_false process.daemonize?
      process = @process_class.new(@server_spy, :daemonize => true)
      assert_false process.daemonize?
    end

    should "ignore blank env values for skip daemonize" do
      ENV['SANFORD_SKIP_DAEMONIZE'] = ''
      process = @process_class.new(@server_spy, :daemonize => true)
      assert_true process.daemonize?
    end

  end

  class RunSetupTests < InitTests
    setup do
      @daemonize_called = false
      Assert.stub(::Process, :daemon).with(true){ @daemonize_called = true }

      @current_process_name = $0

      @term_signal_trap_block = nil
      @term_signal_trap_called = false
      Assert.stub(::Signal, :trap).with("TERM") do |&block|
        @term_signal_trap_block = block
        @term_signal_trap_called = true
      end

      @int_signal_trap_block = nil
      @int_signal_trap_called = false
      Assert.stub(::Signal, :trap).with("INT") do |&block|
        @int_signal_trap_block = block
        @int_signal_trap_called = true
      end

      @usr2_signal_trap_block = nil
      @usr2_signal_trap_called = false
      Assert.stub(::Signal, :trap).with("USR2") do |&block|
        @usr2_signal_trap_block = block
        @usr2_signal_trap_called = true
      end
    end
    teardown do
      $0 = @current_process_name
    end

  end

  class RunTests < RunSetupTests
    desc "and run"
    setup do
      @process.run
    end

    should "not have daemonized the process" do
      assert_false @daemonize_called
    end

    should "have started the server listening" do
      assert_true @server_spy.listen_called
      expected = [ subject.server_ip, subject.server_port ]
      assert_equal expected, @server_spy.listen_args
    end

    should "have set the process name" do
      assert_equal $0, subject.name
    end

    should "have written the PID file" do
      assert_true @pid_file_spy.write_called
    end

    should "have trapped signals" do
      assert_true @term_signal_trap_called
      assert_false @server_spy.stop_called
      @term_signal_trap_block.call
      assert_true @server_spy.stop_called

      assert_true @int_signal_trap_called
      assert_false @server_spy.halt_called
      @int_signal_trap_block.call
      assert_true @server_spy.halt_called

      assert_true @usr2_signal_trap_called
      assert_false @server_spy.pause_called
      @usr2_signal_trap_block.call
      assert_true @server_spy.pause_called
    end

    should "have started the server" do
      assert_true @server_spy.start_called
    end

    should "have joined the server thread" do
      assert_true @server_spy.thread.join_called
    end

    should "not run the restart cmd" do
      assert_false @restart_cmd_spy.run_called
    end

    should "have removed the PID file" do
      assert_true @pid_file_spy.remove_called
    end

  end

  class RunWithDaemonizeTests < RunSetupTests
    desc "that should daemonize is run"
    setup do
      Assert.stub(@process, :daemonize?){ true }
      @process.run
    end

    should "have daemonized the process" do
      assert_true @daemonize_called
    end

  end

  class RunWithServerFDTests < RunSetupTests
    desc "with a server file descriptor is run"
    setup do
      ENV['SANFORD_SERVER_FD'] = Factory.integer.to_s
      @process = @process_class.new(@server_spy)
      @process.run
    end

    should "have used the file descriptor when listening" do
      assert_true @server_spy.listen_called
      expected = [ @process.server_fd ]
      assert_equal expected, @server_spy.listen_args
    end

  end

  class RunWithClientFDsTests < RunSetupTests
    desc "with client file descriptors is run"
    setup do
      @client_fds = [ Factory.integer, Factory.integer ]
      ENV['SANFORD_CLIENT_FDS'] = @client_fds.join(',')
      @process = @process_class.new(@server_spy)
      @process.run
    end

    should "have used the client file descriptors when starting" do
      assert_true @server_spy.start_called
      assert_equal [ @client_fds ], @server_spy.start_args
    end

  end

  class RunAndServerPausedTests < RunSetupTests
    desc "then run and then paused"
    setup do
      server_fd = Factory.integer
      Assert.stub(@server_spy, :file_descriptor){ server_fd }
      client_fds = [ Factory.integer, Factory.integer ]
      Assert.stub(@server_spy, :client_file_descriptors){ client_fds }

      # mimicing pause being called by a signal, after the thread is joined
      @server_spy.thread.on_join{ @server_spy.pause }
      @process.run
    end

    should "set env vars for restarting and run the restart cmd" do
      assert_equal @server_spy.file_descriptor.to_s, ENV['SANFORD_SERVER_FD']
      expected = @server_spy.client_file_descriptors.join(',')
      assert_equal expected, ENV['SANFORD_CLIENT_FDS']
      assert_equal 'yes', ENV['SANFORD_SKIP_DAEMONIZE']
      assert_true @restart_cmd_spy.run_called
    end

  end

  class RestartCmdTests < UnitTests
    desc "RestartCmd"
    setup do
      @current_pwd = ENV['PWD']
      ENV['PWD'] = Factory.path

      @ruby_pwd_stat = File.stat(Dir.pwd)
      env_pwd_stat = File.stat('/dev/null')
      Assert.stub(File, :stat).with(Dir.pwd){ @ruby_pwd_stat }
      Assert.stub(File, :stat).with(ENV['PWD']){ env_pwd_stat }

      @chdir_called_with = nil
      Assert.stub(Dir, :chdir){ |*args| @chdir_called_with = args }

      @exec_called_with = false
      Assert.stub(Kernel, :exec){ |*args| @exec_called_with = args }

      @cmd_class = Sanford::RestartCmd
    end
    teardown do
      ENV['PWD'] = @current_pwd
    end
    subject{ @restart_cmd }

  end

  class RestartCmdInitTests < RestartCmdTests
    desc "when init"
    setup do
      @restart_cmd = @cmd_class.new
    end

    should have_readers :argv, :dir
    should have_imeths :run

    should "know its argv" do
      assert_equal [Gem.ruby, $0, ARGV].flatten, subject.argv
    end

    should "change the dir and run a kernel exec when run" do
      subject.run
      assert_equal [subject.dir], @chdir_called_with
      assert_equal subject.argv,  @exec_called_with
    end

  end

  class RestartCmdWithPWDEnvNoMatchTests < RestartCmdTests
    desc "when init with a PWD env variable that doesn't point to ruby working dir"
    setup do
      @restart_cmd = @cmd_class.new
    end

    should "know its dir" do
      assert_equal Dir.pwd, subject.dir
    end

  end

  class RestartCmdWithPWDEnvInitTests < RestartCmdTests
    desc "when init with a PWD env variable that points to the ruby working dir"
    setup do
      # make ENV['PWD'] point to the same file as Dir.pwd
      Assert.stub(File, :stat).with(ENV['PWD']){ @ruby_pwd_stat }
      @restart_cmd = @cmd_class.new
    end

    should "know its dir" do
      assert_equal ENV['PWD'], subject.dir
    end

  end

  class RestartCmdWithNoPWDEnvInitTests < RestartCmdTests
    desc "when init with a PWD env variable set"
    setup do
      ENV.delete('PWD')
      @restart_cmd = @cmd_class.new
    end

    should "know its dir" do
      assert_equal Dir.pwd, subject.dir
    end

  end

  class ServerSpy
    include Sanford::Server

    name Factory.string
    ip Factory.string
    port Factory.integer
    pid_file Factory.file_path

    attr_reader :listen_called, :start_called
    attr_reader :stop_called, :halt_called, :pause_called
    attr_reader :listen_args, :start_args
    attr_reader :thread

    def initialize(*args)
      super
      @listen_called = false
      @start_called = false
      @stop_called = false
      @halt_called = false
      @pause_called = false

      @listen_args = nil
      @start_args = nil

      @thread = ThreadSpy.new
    end

    def listen(*args)
      @listen_args = args
      @listen_called = true
    end

    def start(*args)
      @start_args = args
      @start_called = true
      @thread
    end

    def stop(*args)
      @stop_called = true
    end

    def halt(*args)
      @halt_called = true
    end

    def pause(*args)
      @pause_called = true
    end

    def paused?
      @pause_called
    end
  end

  class ThreadSpy
    attr_reader :join_called, :on_join_proc

    def initialize
      @join_called = false
      @on_join_proc = proc{ }
    end

    def on_join(&block)
      @on_join_proc = block
    end

    def join
      @join_called = true
      @on_join_proc.call
    end
  end

  class RestartCmdSpy
    attr_reader :run_called

    def initialize
      @run_called = false
    end

    def run
      @run_called = true
    end
  end

end
