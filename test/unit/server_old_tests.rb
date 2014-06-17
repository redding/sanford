require 'assert'
require 'sanford/server_old'

class Sanford::ServerOld

  class UnitTests < Assert::Context
    desc "Sanford::ServerOld"
    setup do
      @server = Sanford::ServerOld.new(TestHost, :keep_alive => true)
    end
    subject{ @server }

    should have_readers :sanford_host, :sanford_host_data, :sanford_host_options
    should have_imeths :on_run, :ip, :port
    should have_imeths :listen, :start, :stop, :halt

    should "save its host and host options but not initialize a host data yet" do
      assert_equal TestHost, subject.sanford_host
      assert_equal true, subject.sanford_host_options[:receives_keep_alive]
      assert_nil subject.sanford_host_data
    end

  end

  class RunTests < UnitTests
    desc "run"
    setup do
      @server.listen(TestHost.ip, TestHost.port)
      @server.start
    end
    teardown do
      @server.stop
    end

    should "have initialized a host data instance" do
      assert_instance_of Sanford::HostData, subject.sanford_host_data
    end

  end

  # Sanford::ServerOld#serve is tested in test/system/request_handling_test.rb,
  # it requires multiple parts of Sanford and basically tests a large portion of
  # the entire system

end
