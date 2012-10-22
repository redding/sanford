require 'assert'

class ManagingTest < Assert::Context
  desc "Using Sanford's manager"

  # preserve the global service hosts configuration, no matter how we
  # manipulate it
  class PreserveServiceHosts < ManagingTest
    setup do
      TestHelper.preserve_and_clear_hosts
    end
    teardown do
      TestHelper.restore_hosts
    end
  end

  class CallTest < ManagingTest
    desc "to run a service host"
    setup do
      @host = FakeHost
      Sanford::Hosts.add(@host)
      options = {
        :ARGV     => [ 'run' ],
        :dir      => @host.config.pid_dir,
        :dir_mode => :normal
      }
      process_name = [ @host.config.hostname, 12345, @host.name ].join('_')
      ::Daemons.expects(:run_proc).with(process_name, options)
    end
    teardown do
      ::Daemons.unstub(:run_proc)
    end

    should "find a service host, build a manager and call the action on it" do
      assert_nothing_raised do
        Sanford::Manager.call(:run, :name => 'FakeHost', :port => 12345)
        Mocha::Mockery.instance.verify
      end
    end
  end

  class BadHostTest < ManagingTest
    desc "with a bad host name"

    should "raise an exception when a service host can't be found" do
      assert_raises(Sanford::NoHost) do
        Sanford::Manager.call(:run, :name => 'not_a_real_host')
      end
    end
  end

  class NoHostsTest < ManagingTest
    desc "with no hosts"
    setup do
      Sanford::Hosts.clear
    end

    should "raise an exception when there aren't any service hosts" do
      assert_raises(Sanford::NoHost) do
        Sanford::Manager.call(:run, :name => 'doesnt_matter')
      end
    end
  end

end
