require 'assert'

module Sanford::Host

  class BaseTest < Assert::Context
    desc "Sanford::Host"
    setup do
      Test::Environment.store_and_clear_hosts
      @host = MyHost.new({ :port => 12345 })
    end
    teardown do
      Test::Environment.restore_hosts
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
      assert_equal 'my.local', subject.config.ip
      assert_equal 12345, subject.config.port
    end
  end

  class InterfaceTest < Assert::Context
    desc "Sanford::Host::Interface"
    subject{ MyHost }

    should have_instance_methods :config, :version
    should have_instance_methods :name, :ip, :port, :pid_dir, :logger

    should "have registered the class with sanford's known hosts" do
      assert_includes subject, Sanford.hosts
    end
  end

  class InvalidTest < BaseTest
    desc "invalid configuration"
    subject{ InvalidHost }

    should "raise a custom exception" do
      assert_raises(Sanford::InvalidHostError){ subject.new }
    end
  end

  class VersionTest < BaseTest
    desc "version class method"
    setup do
      MyHost.version('v1'){ }
    end

    should "have added a version hash to the versioned_services config" do
      assert_equal({}, MyHost.config.versioned_services["v1"])
    end
  end

end
