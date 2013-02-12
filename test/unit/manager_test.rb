require 'assert'

require 'sanford/cli'

class Sanford::Manager

  class BaseTest < Assert::Context
    desc "Sanford::Manager"
    setup do
      @manager = Sanford::Manager.new({ :host => 'TestHost' })
    end
    subject{ @manager }

    should have_instance_methods :host, :ip, :port, :process_name, :pid_file
    should have_instance_methods :run, :start, :stop, :restart
    should have_class_methods :call

    should "find a host based on the `host` option" do
      assert_equal TestHost, subject.host
    end

    should "set the ip, port and pid file based on the host's configuration" do
      assert_equal TestHost.ip,   subject.ip
      assert_equal TestHost.port, subject.port
      assert_includes TestHost.pid_dir, subject.pid_file.to_s
    end

    should "build a process name based on the name of the host, ip and port" do
      assert_equal "TestHost_#{subject.ip}_#{subject.port}.pid", subject.process_name
    end

    should "build a pid_file based on the host and the process name" do
      assert_instance_of Sanford::Manager::PIDFile, subject.pid_file
      assert_equal File.join(TestHost.pid_dir, subject.process_name), subject.pid_file.to_s
    end

    should "use the first host if no host option is provided" do
      manager = Sanford::Manager.new({ :port => 1 })
      assert_equal Sanford.hosts.first, manager.host
    end

    should "raise an error when a host can't be found matching the `host` option" do
      assert_raises(Sanford::NoHostError) do
        Sanford::Manager.new({ :host => 'poop' })
      end
    end

    should "raise an error when a host is invalid for running a server" do
      assert_raises(Sanford::InvalidHostError) do
        Sanford::Manager.new({ :host => 'InvalidHost' })
      end
    end

  end

  class EnvVarsTest < BaseTest
    desc "with env vars set"
    setup do
      ENV['SANFORD_HOST'] = 'TestHost'
      ENV['SANFORD_IP']   = '127.0.0.1'
      ENV['SANFORD_PORT'] = '12345'
      @manager = Sanford::Manager.new({
        :host => 'InvalidHost',
        :port => 54678
      })
    end
    teardown do
      ENV.delete('SANFORD_HOST')
      ENV.delete('SANFORD_IP')
      ENV.delete('SANFORD_PORT')
    end

    should "use the env vars over passed in options or the host's configuration" do
      assert_equal TestHost,    subject.host
      assert_equal '127.0.0.1', subject.ip
      assert_equal 12345,       subject.port
    end

  end

  # Sanford::Manager run, start, stop and restart are tested with system tests:
  #   test/system/managing_test.rb

end
