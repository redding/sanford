require 'assert'

require 'sanford/cli'

class ManagingTest < Assert::Context
  include Test::ManagerHelper
  desc "Using Sanford's Manager"

  class RunTest < ManagingTest
    desc "to run a server"
    setup do
      @proc = proc{ Sanford::Manager.call(:run, :host => 'TestHost') }
    end

    should "run the server specified and write a PID file" do
      self.fork_and_call(@proc) do
        assert_nothing_raised{ self.open_socket('localhost', 12000) }
        assert File.exists?('tmp/localhost_12000_TestHost.pid')
      end
    end

  end

  class StartTest < ManagingTest
    desc "to start a daemonized server"
    setup do
      @proc = proc{ Sanford::Manager.call(:start, :host => 'TestHost') }
    end
    teardown do
      Sanford::Manager.call(:stop, :host => 'TestHost')
    end

    should "run the server specified and write a PID file" do
      self.fork_and_call(@proc) do
        assert_nothing_raised{ self.open_socket('localhost', 12000) }
        assert File.exists?('tmp/localhost_12000_TestHost.pid')
      end
    end

  end

  class StopTest < ManagingTest
    desc "to stop a daemonized server"
    setup do
      @start_proc = proc{ Sanford::Manager.call(:start, :host => 'TestHost') }
    end

    should "stop the server specified and remove the PID file" do
      self.fork_and_call(@start_proc) do
        Sanford::Manager.call(:stop, :host => 'TestHost')
        sleep 1

        assert_raises{ self.open_socket('localhost', 12000) }
        assert_not File.exists?('tmp/localhost_12000_TestHost.pid')
      end
    end

  end

  class RestartTest < ManagingTest
    # TODO
  end

end
