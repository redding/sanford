require 'assert'

require 'sanford/cli'

class ManagingTest < Assert::Context
  include Test::ManagerHelper
  desc "Using Sanford's Manager"
  setup do
    @start_options = { :host => 'MyHost', :ip => 'localhost', :port => 12345 }
  end

  class RunTest < ManagingTest
    desc "to run a server"
    setup do
      @proc = proc{ Sanford::Manager.call(:run, @start_options) }
    end

    should "run the server specified and write a PID file" do
      self.fork_and_call(@proc) do
        assert_nothing_raised{ self.open_socket('localhost', 12345) }
        assert File.exists?('tmp/my_host_localhost_12345.pid')
      end
    end

  end

  class StartTest < ManagingTest
    desc "to start a daemonized server"
    setup do
      @proc = proc{ Sanford::Manager.call(:start, @start_options) }
    end
    teardown do
      Sanford::Manager.call(:stop, @start_options)
    end

    should "run the server specified and write a PID file" do
      self.fork_and_call(@proc) do
        assert_nothing_raised{ self.open_socket('localhost', 12345) }
        assert File.exists?('tmp/my_host_localhost_12345.pid')
      end
    end

  end

  class StopTest < ManagingTest
    desc "to stop a daemonized server"
    setup do
      @start_proc = proc{ Sanford::Manager.call(:start, @start_options) }
    end

    should "stop the server specified and remove the PID file" do
      self.fork_and_call(@start_proc) do
        Sanford::Manager.call(:stop, @start_options)
        sleep 1

        assert_raises{ self.open_socket('localhost', 12345) }
        assert_not File.exists?('tmp/my_host_localhost_12345.pid')
      end
    end

  end

  class RestartTest < ManagingTest
    # TODO
  end

end
