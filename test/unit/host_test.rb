require 'assert'

module Sanford::Host

  class BaseTest < Assert::Context
    desc "Sanford::Host"
    setup do
      TestHelper.preserve_and_clear_hosts
      @host_class = Class.new do
        include Sanford::Host
        name 'anonymous_host'
        configure do
          host 'anonymous.local'
        end
      end
      @host = @host_class.new({ :port => 12345 })
    end
    teardown do
      TestHelper.restore_hosts
    end
    subject{ @host }

    should have_instance_methods :name, :config

    should "set name to it's class #name" do
      assert_equal subject.class.name, subject.name
    end
    should "proxy missing methods to it's config" do
      assert_equal subject.config.port, subject.port
      assert subject.respond_to?(:pid_dir)
    end
    should "default it's configuration from the class and overwrite with values passed to new" do
      assert_equal 'anonymous.local', subject.config.host
      assert_equal 12345, subject.config.port
    end
  end

  class ConfigTest < BaseTest
    desc "config"
    setup do
      @config = @host.config
    end
    subject{ @config }

    should have_instance_methods :hostname, :port, :pid_dir, :logging, :logger
  end

  class ClassMethodsTest < BaseTest
    desc "class methods"
    subject{ @host_class }

    should have_instance_methods :name, :config, :configure

    should "have registered the class with sanford's known hosts" do
      assert_includes subject, Sanford::Hosts.set
    end
  end

  class InvalidTest < BaseTest
    desc "invalid configuration"
    setup do
      @host_class = Class.new do
        include Sanford::Host
        name 'invalid_host'
      end
    end

    should "raise a custom exception" do
      assert_raises(Sanford::InvalidHost) do
        @host_class.new
      end
    end
  end

end
