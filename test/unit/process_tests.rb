require 'assert'
require 'sanford/process'

require 'sanford/io_pipe'
require 'sanford/server'
require 'test/support/pid_file_spy'

class Sanford::Process

  class UnitTests < Assert::Context
    desc "Sanford::Process"
    setup do
      @current_env_server_fd      = ENV['SANFORD_SERVER_FD']
      @current_env_client_fds     = ENV['SANFORD_CLIENT_FDS']
      @current_env_skip_daemonize = ENV['SANFORD_SKIP_DAEMONIZE']
      ENV.delete('SANFORD_SERVER_FD')
      ENV.delete('SANFORD_CLIENT_FDS')
      ENV.delete('SANFORD_SKIP_DAEMONIZE')

      @process_class = Sanford::Process
    end
    teardown do
      ENV['SANFORD_SKIP_DAEMONIZE'] = @current_env_skip_daemonize
      ENV['SANFORD_CLIENT_FDS']     = @current_env_client_fds
      ENV['SANFORD_SERVER_FD']      = @current_env_server_fd
    end
    subject{ @process_class }

    should "know its wait for signals timeout" do
      assert_equal 15, WAIT_FOR_SIGNALS_TIMEOUT
    end

    should "know its signal strings" do
      assert_equal 'H', HALT
      assert_equal 'S', STOP
      assert_equal 'R', RESTART
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @server_spy = ServerSpy.new

      @pid_file_spy = PIDFileSpy.new(Factory.integer)
      Assert.stub(Sanford::PIDFile, :new).with(@server_spy.pid_file) do
        @pid_file_spy
      end

      @restart_cmd_spy = RestartCmdSpy.new
      Assert.stub(Sanford::RestartCmd, :new){ @restart_cmd_spy }

      @process = @process_class.new(@server_spy)
    end
    subject{ @process }

    should have_readers :server, :name, :pid_file, :signal_io, :restart_cmd
    should have_readers :server_ip, :server_port, :server_fd, :client_fds
    should have_imeths :run, :daemonize?

    should "know its server" do
      assert_equal @server_spy, subject.server
    end

    should "know its name, pid file, signal io and restart cmd" do
      exp = "sanford: #{@server_spy.process_label}"
      assert_equal exp, subject.name

      assert_equal @pid_file_spy,         subject.pid_file
      assert_instance_of Sanford::IOPipe, subject.signal_io
      assert_equal @restart_cmd_spy,      subject.restart_cmd
    end

    should "know its server ip, port and file descriptor" do
      assert_equal @server_spy.configured_ip,   subject.server_ip
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

      @signal_traps = []
      Assert.stub(::Signal, :trap) do |signal, &block|
        @signal_traps << SignalTrap.new(signal, block)
      end
    end
    teardown do
      @process.signal_io.write(HALT)
      @thread.join if @thread
      $0 = @current_process_name
    end

  end

  class RunTests < RunSetupTests
    desc "and run"
    setup do
      @wait_timeout = nil
      Assert.stub(@process.signal_io, :wait) do |timeout|
        @wait_timeout = timeout
        sleep 2*JOIN_SECONDS
        false
      end

      @thread = Thread.new{ @process.run }
      @thread.join(JOIN_SECONDS)
    end
    teardown do
      # manually unstub or the process thread will hang forever
      Assert.unstub(@process.signal_io, :wait)
    end

    should "not daemonize the process" do
      assert_false @daemonize_called
    end

    should "start the server listening" do
      assert_true @server_spy.listen_called
      exp = [subject.server_ip, subject.server_port]
      assert_equal exp, @server_spy.listen_args
    end

    should "set the process name" do
      assert_equal $0, subject.name
    end

    should "write its PID file" do
      assert_true @pid_file_spy.write_called
    end

    should "trap signals" do
      assert_equal 3, @signal_traps.size
      assert_equal ['INT', 'TERM', 'USR2'], @signal_traps.map(&:signal)
    end

    should "start the server" do
      assert_true @server_spy.start_called
    end

    should "sleep its thread waiting for signals" do
      assert_equal WAIT_FOR_SIGNALS_TIMEOUT, @wait_timeout
      assert_equal 'sleep', @thread.status
    end

    should "not run the restart cmd" do
      assert_nil @restart_cmd_spy.run_called_for
    end

  end

  class SignalTrapsTests < RunSetupTests
    desc "signal traps"
    setup do
      # setup the io pipe so we can see whats written to it
      @process.signal_io.setup
    end
    teardown do
      @process.signal_io.teardown
    end

    should "write the signals to processes signal IO" do
      @signal_traps.each do |signal_trap|
        signal_trap.block.call
        assert_equal signal_trap.signal, subject.signal_io.read
      end
    end

  end

  class RunWithDaemonizeTests < RunSetupTests
    desc "that should daemonize is run"
    setup do
      Assert.stub(@process, :daemonize?){ true }
      @thread = Thread.new{ @process.run }
      @thread.join(JOIN_SECONDS)
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
      @thread = Thread.new{ @process.run }
      @thread.join(JOIN_SECONDS)
    end

    should "have used the file descriptor when listening" do
      assert_true @server_spy.listen_called
      exp = [@process.server_fd]
      assert_equal exp, @server_spy.listen_args
    end

  end

  class RunWithClientFDsTests < RunSetupTests
    desc "with client file descriptors is run"
    setup do
      @client_fds = [ Factory.integer, Factory.integer ]
      ENV['SANFORD_CLIENT_FDS'] = @client_fds.join(',')
      @process = @process_class.new(@server_spy)
      @thread = Thread.new{ @process.run }
      @thread.join(JOIN_SECONDS)
    end

    should "have used the client file descriptors when starting" do
      assert_true @server_spy.start_called
      assert_equal [ @client_fds ], @server_spy.start_args
    end

  end

  class RunAndHaltTests < RunSetupTests
    desc "and run with a halt signal"
    setup do
      @thread = Thread.new{ @process.run }
      @thread.join(JOIN_SECONDS)
      @process.signal_io.write(HALT)
      @thread.join(JOIN_SECONDS)
    end

    should "halt its server" do
      assert_true @server_spy.halt_called
      assert_equal [true], @server_spy.halt_args
    end

    should "not set the env var to skip daemonize" do
      assert_equal @current_env_skip_daemonize, ENV['SANFORD_SKIP_DAEMONIZE']
    end

    should "not run the restart cmd" do
      assert_nil @restart_cmd_spy.run_called_for
    end

    should "remove the PID file" do
      assert_true @pid_file_spy.remove_called
    end

  end

  class RunAndStopTests < RunSetupTests
    desc "and run with a stop signal"
    setup do
      @thread = Thread.new{ @process.run }
      @thread.join(JOIN_SECONDS)
      @process.signal_io.write(STOP)
      @thread.join(JOIN_SECONDS)
    end

    should "stop its server" do
      assert_true @server_spy.stop_called
      assert_equal [true], @server_spy.stop_args
    end

    should "not set the env var to skip daemonize" do
      assert_equal @current_env_skip_daemonize, ENV['SANFORD_SKIP_DAEMONIZE']
    end

    should "not run the restart cmd" do
      assert_nil @restart_cmd_spy.run_called_for
    end

    should "remove the PID file" do
      assert_true @pid_file_spy.remove_called
    end

  end

  class RunAndRestartTests < RunSetupTests
    desc "and run with a restart signal"
    setup do
      @thread = Thread.new{ @process.run }
      @thread.join(JOIN_SECONDS)
      @process.signal_io.write(RESTART)
      @thread.join(JOIN_SECONDS)
    end

    should "pause its server" do
      assert_true @server_spy.pause_called
      assert_equal [true], @server_spy.pause_args
    end

    should "run the restart cmd" do
      assert_equal @server_spy, @restart_cmd_spy.run_called_for
    end

  end

  class RunWithServerCrashTests < RunSetupTests
    desc "and run with the server crashing"
    setup do
      Assert.stub(@process.signal_io, :wait) do |timeout|
        sleep JOIN_SECONDS * 0.5 # ensure this has time to run before the thread
                                 # joins below
        false
      end

      @thread = Thread.new{ @process.run }
      @thread.join(JOIN_SECONDS)
      @server_spy.start_called = false
      @thread.join(JOIN_SECONDS)
    end
    teardown do
      # manually unstub or the process thread will hang forever
      Assert.unstub(@process.signal_io, :wait)
    end

    should "re-start its server" do
      assert_true @server_spy.start_called
    end

  end

  class RunWithInvalidSignalTests < RunSetupTests
    desc "and run with unsupported signals"
    setup do
      # ruby throws an argument error if the OS doesn't support a signal
      Assert.stub(::Signal, :trap){ raise ArgumentError }

      @thread = Thread.new{ @process.run }
      @thread.join(JOIN_SECONDS)
    end

    should "start normally" do
      assert_true @server_spy.start_called
      assert_equal 'sleep', @thread.status
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

      @server_spy = ServerSpy.new
      server_fd = Factory.integer
      Assert.stub(@server_spy, :file_descriptor){ server_fd }
      client_fds = Factory.integer(3).times.map{ Factory.integer }
      Assert.stub(@server_spy, :client_file_descriptors){ client_fds }

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

    if RUBY_VERSION == '1.8.7'

      should "set env vars, change the dir and kernel exec when run" do
        subject.run(@server_spy)

        assert_equal @server_spy.file_descriptor.to_s, ENV['SANFORD_SERVER_FD']
        exp = @server_spy.client_file_descriptors.join(',')
        assert_equal exp, ENV['SANFORD_CLIENT_FDS']
        assert_equal 'yes', ENV['SANFORD_SKIP_DAEMONIZE']

        assert_equal [subject.dir], @chdir_called_with
        assert_equal subject.argv,  @exec_called_with
      end

    else

      should "kernel exec when run" do
        subject.run(@server_spy)

        env = {
          'SANFORD_SERVER_FD'      => @server_spy.file_descriptor.to_s,
          'SANFORD_CLIENT_FDS'     => @server_spy.client_file_descriptors.join(','),
          'SANFORD_SKIP_DAEMONIZE' => 'yes'
        }
        fd_redirects = (
          [@server_spy.file_descriptor] +
          @server_spy.client_file_descriptors
        ).inject({}){ |h, fd| h.merge!(fd => fd) }
        options = { :chdir => subject.dir }.merge!(fd_redirects)
        assert_equal ([env] + subject.argv + [options]), @exec_called_with
      end

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

  SignalTrap = Struct.new(:signal, :block)

  class ServerSpy
    include Sanford::Server

    name     Factory.string
    ip       Factory.string
    port     Factory.integer
    pid_file Factory.file_path

    attr_accessor :process_label, :listen_called
    attr_accessor :start_called, :stop_called, :halt_called, :pause_called
    attr_reader :listen_args, :start_args, :stop_args, :halt_args, :pause_args

    def initialize(*args)
      super

      @process_label = Factory.string

      @listen_args   = nil
      @listen_called = false
      @start_args    = nil
      @start_called  = false
      @stop_args     = nil
      @stop_called   = false
      @halt_args     = nil
      @halt_called   = false
      @pause_args    = nil
      @pause_called  = false
    end

    def listen(*args)
      @listen_args = args
      @listen_called = true
    end

    def start(*args)
      @start_args = args
      @start_called = true
    end

    def stop(*args)
      @stop_args   = args
      @stop_called = true
    end

    def halt(*args)
      @halt_args   = args
      @halt_called = true
    end


    def pause(*args)
      @pause_args   = args
      @pause_called = true
    end

    def running?
      !!@start_called
    end
  end

  class RestartCmdSpy
    attr_reader :run_called_for

    def initialize
      @run_called_for = nil
    end

    def run(server)
      @run_called_for = server
    end
  end

end
