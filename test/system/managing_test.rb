require 'assert'

class ManagingTest < Assert::Context
  desc "Using Sanford's manager"
  setup do
    # preserve the global service hosts configuration, no matter how we
    # manipulate it
    Test::Environment.store_and_clear_hosts
  end
  teardown do
    Test::Environment.restore_hosts
  end

  class CallTest < ManagingTest
    include Test::ForkManagerHelper

    setup do
      Sanford.config.hosts.add(DummyHost)
    end
  end

  class RunTest < CallTest
    desc "to run a service host"

    should "start a sanford server for the only service host that is configured" do
      host = Sanford.config.hosts.first

      self.call_sanford_manager(:run) do
        assert_nothing_raised{ self.open_socket(host.config.ip, host.config.port) }
        assert File.exists?(self.expected_pid_file(host, host.config.ip, host.config.port))
      end
    end
  end

  class RunWithOptionsTest < CallTest
    desc "to run a service host and passing options"
    setup do
      # make sure that DummyHost isn't the only 'host'
      Sanford.config.hosts.add(Class.new)
    end

    should "start a sanford server for the specified service host and " \
           "use the passed options to override it's configuration" do
      host = Sanford.config.find_host('DummyHost')

      self.call_sanford_manager(:run, { :host => 'DummyHost', :port => 12345 }) do
        assert_nothing_raised{ self.open_socket(host.config.ip, 12345) }
        assert File.exists?(self.expected_pid_file(host, host.config.ip, 12345))
      end
    end
  end

  class RunWithEnvVarsTest < CallTest
    desc "to run a service host and setting env vars"
    setup do
      @current = ENV.delete('SANFORD_HOST'), ENV.delete('SANFORD_IP'), ENV.delete('SANFORD_PORT')
      ENV['SANFORD_HOST'] = 'DummyHost'
      ENV['SANFORD_IP'], ENV['SANFORD_PORT'] = 'localhost', '54321'
      # make sure that DummyHost isn't the only 'host'
      Sanford.config.hosts.add(Class.new)
    end
    teardown do
      ENV['SANFORD_HOST'], ENV['SANFORD_IP'], ENV['SANFORD_PORT'] = @current
    end

    should "start a sanford server for the specified service host and " \
           "use the env vars to override it's configuration" do
      host = Sanford.config.find_host(ENV['SANFORD_HOST'])
      port = ENV['SANFORD_PORT'].to_i

      self.call_sanford_manager(:run) do
        assert_nothing_raised{ self.open_socket(ENV['SANFORD_IP'], port) }
        assert File.exists?(self.expected_pid_file(host, ENV['SANFORD_IP'], port))
      end
    end
  end

  class BadHostTest < ManagingTest
    desc "with a bad host name"
    setup do
      Sanford.config.hosts.clear
      Sanford.config.hosts.add(Class.new)
    end

    should "raise an exception when a service host can't be found" do
      assert_raises(Sanford::NoHostError) do
        Sanford::Manager.call(:run, :host => 'not_a_real_host')
      end
    end
  end

  class NoHostsTest < ManagingTest
    desc "with no hosts"
    setup do
      Sanford.config.hosts.clear
    end

    should "raise an exception when there aren't any service hosts" do
      assert_raises(Sanford::NoHostError) do
        Sanford::Manager.call(:run)
      end
    end
  end

end
