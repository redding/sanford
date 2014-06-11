require 'assert'
require 'sanford/manager'

module Sanford::Manager

  class UnitTests < Assert::Context
    desc "Sanford::Manager"
    subject{ Sanford::Manager }

    should have_imeths :call, :get_handler_class

    should "return ServerHandler or SignalHandler with get_handler_class" do
      assert_equal Sanford::Manager::ServerHandler, subject.get_handler_class('run')
      assert_equal Sanford::Manager::ServerHandler, subject.get_handler_class('start')
      assert_equal Sanford::Manager::SignalHandler, subject.get_handler_class('stop')
      assert_equal Sanford::Manager::SignalHandler, subject.get_handler_class('restart')
    end

  end

  class ConfigTests < UnitTests
    desc "Config"
    setup do
      @config = Sanford::Manager::Config.new({ :host => 'TestHost' })
    end
    subject{ @config }

    should have_readers :host_name, :host, :ip, :port, :pid, :pid_file, :restart_dir
    should have_readers :file_descriptor, :client_file_descriptors
    should have_imeths :listen_args, :has_listen_args?, :found_host?

    should "find a host based on the `host` option" do
      assert_equal TestHost, subject.host
      assert_equal true, subject.found_host?
    end

    should "set the ip, port and pid file based on the host's configuration" do
      assert_equal TestHost.ip,            subject.ip
      assert_equal TestHost.port,          subject.port
      assert_equal TestHost.pid_file.to_s, subject.pid_file.to_s
    end

    should "use the first host if no host option is provided" do
      config = Sanford::Manager::Config.new({ :port => 1 })
      assert_equal Sanford.hosts.first, config.host
    end

    should "return the file descriptor or ip and port with listen_args" do
      config = Sanford::Manager::Config.new({
        :file_descriptor => 1,
        :ip => 'localhost', :port => 1234
      })
      assert_equal [ config.file_descriptor ], config.listen_args
      assert_equal true, subject.has_listen_args?

      config = Sanford::Manager::Config.new({ :ip => 'localhost', :port => 1234 })
      assert_equal [ config.ip, config.port ], config.listen_args
      assert_equal true, subject.has_listen_args?

      config = Sanford::Manager::Config.new({ :host => 'InvalidHost' })
      assert_equal false, config.has_listen_args?
    end

    should "build a NullHost when a host can't be found" do
      config = Sanford::Manager::Config.new({ :host => 'poop' })
      assert_instance_of Sanford::Manager::Config::NullHost, config.host
      assert_equal false, config.found_host?
    end

    should "split a string list of client file descriptors into an array" do
      config = Sanford::Manager::Config.new({ :client_fds => '1,2,3' })
      assert_equal [ 1, 2, 3 ], config.client_file_descriptors
    end

  end

  class EnvVarsTests < ConfigTests
    desc "with env vars set"
    setup do
      ENV['SANFORD_HOST'] = 'TestHost'
      ENV['SANFORD_IP']   = '127.0.0.1'
      ENV['SANFORD_PORT'] = '12345'
      @config = Sanford::Manager::Config.new({
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

  class PIDFileTests < ConfigTests
    desc "PIDFile"
    setup do
      @pid_file_path = File.join(ROOT, "tmp/my.pid")
      @pid_file = Sanford::Manager::Config::PIDFile.new(@pid_file_path)
    end
    teardown do
      FileUtils.rm_rf(@pid_file_path)
    end
    subject{ @pid_file }

    should have_imeths :pid, :to_s, :write, :remove

    should "return its path with #to_s" do
      assert_equal @pid_file_path, subject.to_s
    end

    should "write the pid file with #write" do
      subject.write

      assert_file_exists @pid_file_path
      assert_equal "#{Process.pid}\n", File.read(@pid_file_path)
    end

    should "return the value stored in the pid value with #pid" do
      subject.write

      assert_equal Process.pid, subject.pid
    end

    should "remove the file with #remove" do
      subject.write
      subject.remove

      assert_not File.exists?(@pid_file_path)
    end

    should "complain nicely if it can't write the pid file" do
      pid_file_path = 'does/not/exist.pid'
      pid_file = Sanford::Manager::Config::PIDFile.new(pid_file_path)

      err = nil
      begin
        pid_file.write
      rescue Exception => err
      end

      assert err
      assert_kind_of RuntimeError, err
      assert_includes File.dirname(pid_file_path), err.message
    end

  end

  class ServerHandlerTests < UnitTests
    desc "ServerHandler"
    setup do
      @handler = Sanford::Manager::ServerHandler.new({ :host => 'TestHost' })
    end
    subject{ @handler }

    should have_imeths :run, :start

    should "raise an error when a host can't be found" do
      assert_raises(Sanford::NoHostError) do
        Sanford::Manager::ServerHandler.new({ :host => 'not_found' })
      end
    end

    should "raise an error when a host is invalid for running a server" do
      assert_raises(Sanford::InvalidHostError) do
        Sanford::Manager::ServerHandler.new({ :host => 'InvalidHost' })
      end
    end

  end

  class SignalHandlertests < UnitTests
    desc "SignalHandler"
    setup do
      @handler = Sanford::Manager::SignalHandler.new({ :pid => -1 })
    end
    subject{ @handler }

    should have_imeths :stop, :restart

    should "raise an error when a pid can't be found" do
      assert_raises(Sanford::NoPIDError) do
        Sanford::Manager::SignalHandler.new
      end
    end
  end

end
