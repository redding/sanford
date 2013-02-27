require 'assert'

require 'sanford/cli'

module Sanford::Manager

  class BaseTest < Assert::Context
    desc "Sanford::Manager"
    subject{ Sanford::Manager }

    should have_instance_methods :call, :get_handler_class

    should "return ServerHandler or SignalHandler with get_handler_class" do
      assert_equal Sanford::Manager::ServerHandler, subject.get_handler_class('run')
      assert_equal Sanford::Manager::ServerHandler, subject.get_handler_class('start')
      assert_equal Sanford::Manager::SignalHandler, subject.get_handler_class('stop')
      assert_equal Sanford::Manager::SignalHandler, subject.get_handler_class('restart')
    end

  end

  class ServerHandlerTest < BaseTest
    desc "ServerHandler"
    setup do
      @handler = Sanford::Manager::ServerHandler.new({ :host => 'TestHost' })
    end
    subject{ @handler }

    should have_instance_methods :run, :start

    should "raise an error when a host can't be found matching the `host` option" do
      assert_raises(Sanford::NoHostError) do
        Sanford::Manager::ServerHandler.new({ :host => 'poop' })
      end
    end

    should "raise an error when a host is invalid for running a server" do
      assert_raises(Sanford::InvalidHostError) do
        Sanford::Manager::ServerHandler.new({ :host => 'InvalidHost' })
      end
    end

  end

  class SignalHandlertest < BaseTest
    desc "SignalHandler"
    setup do
      @handler = Sanford::Manager::SignalHandler.new({ :pid => -1 })
    end
    subject{ @handler }

    should have_instance_methods :stop, :restart

    should "raise an error when a pid can't be found" do
      assert_raises(Sanford::NoPIDError) do
        Sanford::Manager::SignalHandler.new
      end
    end
  end

  class ConfigTest < BaseTest
    desc "Config"
    setup do
      @config = Sanford::Manager::Config.new({ :host => 'TestHost' })
    end
    subject{ @config }

    should have_instance_methods :host_name, :host, :ip, :port, :pid, :pid_file
    should have_instance_methods :file_descriptor, :client_file_descriptors
    should have_instance_methods :restart_dir
    should have_instance_methods :listen_args, :has_listen_args?, :found_host?

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
      manager = Sanford::Manager::Config.new({ :port => 1 })
      assert_equal Sanford.hosts.first, manager.host
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
      assert_instance_of Sanford::Manager::NullHost, config.host
      assert_equal false, config.found_host?
    end

    should "split a string list of client file descriptors into an array" do
      config = Sanford::Manager::Config.new({ :client_fds => '1,2,3' })
      assert_equal [ 1, 2, 3 ], config.client_file_descriptors
    end

  end

  class EnvVarsTest < ConfigTest
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

end
