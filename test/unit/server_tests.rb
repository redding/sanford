require 'assert'
require 'sanford/server'

class Sanford::Server

  class UnitTests < Assert::Context
    desc "Sanford::Server"
    setup do
      @server = Sanford::Server.new(TestHost, :keep_alive => true)
    end
    subject{ @server }

    should have_readers :sanford_host, :sanford_host_data, :sanford_host_options
    should have_imeths :on_run

    should "include DatTCP::Server" do
      assert_includes DatTCP::Server, subject.class
    end

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
      @server.run
    end
    teardown do
      @server.stop
    end

    should "have initialized a host data instance" do
      assert_instance_of Sanford::HostData, subject.sanford_host_data
    end

  end

  # Sanford::Server#serve is tested in test/system/request_handling_test.rb,
  # it requires multiple parts of Sanford and basically tests a large portion of
  # the entire system

end
