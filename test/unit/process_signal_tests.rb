require 'assert'
require 'sanford/process_signal'

require 'test/support/pid_file_spy'

class Sanford::ProcessSignal

  class UnitTests < Assert::Context
    desc "Sanford::ProcessSignal"
    setup do
      @server = TestServer.new
      @signal = Factory.string

      @pid_file_spy = PIDFileSpy.new(Factory.integer)
      Assert.stub(Sanford::PIDFile, :new).with(@server.pid_file) do
        @pid_file_spy
      end

      @process_signal = Sanford::ProcessSignal.new(@server, @signal)
    end
    subject{ @process_signal }

    should have_readers :signal, :pid
    should have_imeths :send

    should "know its signal and pid" do
      assert_equal @signal, subject.signal
      assert_equal @pid_file_spy.pid, subject.pid
    end

  end

  class SendTests < UnitTests
    desc "when sent"
    setup do
      @kill_called = false
      Assert.stub(::Process, :kill).with(@signal, @pid_file_spy.pid) do
        @kill_called = true
      end

      @process_signal.send
    end

    should "have used process kill to send the signal to the PID" do
      assert_true @kill_called
    end

  end

  class TestServer
    include Sanford::Server

    name Factory.string
    ip Factory.string
    port Factory.integer
    pid_file Factory.file_path

  end

end
