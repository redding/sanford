require 'assert'
require 'sanford/cli'

require 'sanford/server'

class Sanford::CLI

  class UnitTests < Assert::Context
    desc "Sanford::CLI"
    setup do
      @cli_class = Sanford::CLI
    end
    subject{ @cli_class }

    should have_imeths :run

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @kernel_spy = KernelSpy.new
      @file_path = Factory.file_path

      @server = TestServer.new

      @config_file = FakeConfigFile.new(@server)
      Assert.stub(Sanford::ConfigFile, :new).with(@file_path){ @config_file }

      @process_spy = ProcessSpy.new
      @process_signal_spy = ProcessSignalSpy.new

      @cli = Sanford::CLI.new(@kernel_spy)
    end
    subject{ @cli }

    should have_imeths :run

  end

  class DefaultsTests < InitTests
    setup do
      Assert.stub(Sanford::ConfigFile, :new).with('config.sanford'){ @config_file }
      Assert.stub(Sanford::Process, :new).with(@server, :daemonize => false) do
        @process_spy
      end
    end

    should "default the command when its not provided" do
      subject.run(@file_path)
      assert_true @process_spy.run_called
    end

    should "default the command and file path when they aren't provided" do
      subject.run
      assert_true @process_spy.run_called
    end

  end

  class RunTests < InitTests
    desc "with the run command"
    setup do
      Assert.stub(Sanford::Process, :new).with(@server, :daemonize => false) do
        @process_spy
      end
      @cli.run(@file_path, 'run')
    end

    should "have built and run a non-daemonized process" do
      assert_true @process_spy.run_called
    end

  end

  class StartTests < InitTests
    desc "with the start command"
    setup do
      Assert.stub(Sanford::Process, :new).with(@server, :daemonize => true) do
        @process_spy
      end

      @cli.run(@file_path, 'start')
    end

    should "have built and run a daemonized process" do
      assert_true @process_spy.run_called
    end

  end

  class StopTests < InitTests
    desc "with the stop command"
    setup do
      Assert.stub(Sanford::ProcessSignal, :new).with(@server, 'TERM') do
        @process_signal_spy
      end

      @cli.run(@file_path, 'stop')
    end

    should "have built and sent a TERM signal" do
      assert_true @process_signal_spy.send_called
    end

  end

  class RestartTests < InitTests
    desc "with the restart command"
    setup do
      Assert.stub(Sanford::ProcessSignal, :new).with(@server, 'USR2') do
        @process_signal_spy
      end

      @cli.run(@file_path, 'restart')
    end

    should "have built and sent a USR2 signal" do
      assert_true @process_signal_spy.send_called
    end

  end

  class InvalidCommandTests < InitTests
    desc "with an invalid command"
    setup do
      @command = Factory.string
      @cli.run(@file_path, @command)
    end

    should "output the error with the help" do
      expected = "#{@command.inspect} is not a valid command"
      assert_includes expected, @kernel_spy.output
      assert_includes "Usage: sanford", @kernel_spy.output
    end

  end

  class KernelSpy
    attr_reader :exit_status

    def initialize
      @output = StringIO.new
      @exit_status = nil
    end

    def output
      @output.rewind
      @output.read
    end

    def puts(message)
      @output.puts(message)
    end

    def exit(code)
      @exit_status = code
    end
  end

  class TestServer
    include Sanford::Server

    name Factory.string
    ip Factory.string
    port Factory.integer
  end

  FakeConfigFile = Struct.new(:server)

  class ProcessSpy
    attr_reader :run_called

    def initialize
      @run_called = false
    end

    def run
      @run_called = true
    end
  end

  class ProcessSignalSpy
    attr_reader :send_called

    def initialize
      @send_called = false
    end

    def send
      @send_called = true
    end
  end

end
