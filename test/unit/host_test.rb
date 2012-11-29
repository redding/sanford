require 'assert'

module Sanford::Host

  class BaseTest < Assert::Context
    desc "Sanford::Host"
    setup do
      Test::Environment.store_and_clear_hosts
      @host_class = Class.new do
        include Sanford::Host
        name  'anonymous_host'
        ip    'anonymous.local'
      end
      @host = @host_class.new({ :port => 12345 })
    end
    teardown do
      Test::Environment.restore_hosts
    end
    subject{ @host }

    should have_instance_methods :name, :config, :run

    should "set name to it's class #name" do
      assert_equal subject.class.name, subject.name
    end

    should "proxy missing methods to it's config" do
      assert_equal subject.config.port, subject.port
      assert subject.respond_to?(:pid_dir)
    end

    should "default it's configuration from the class and overwrite with values passed to new" do
      assert_equal 'anonymous.local', subject.config.ip
      assert_equal 12345, subject.config.port
    end
  end

  class ConfigTest < BaseTest
    desc "config"
    setup do
      @config = @host.config
    end
    subject{ @config }

    should have_instance_methods :name, :ip, :port, :pid_dir, :logger
  end

  class ClassMethodsTest < BaseTest
    desc "class methods"
    subject{ @host_class }

    should have_instance_methods :config, :version
    should have_instance_methods :name, :ip, :port, :pid_dir, :logger

    should "have registered the class with sanford's known hosts" do
      assert_includes subject, Sanford.config.hosts
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
      assert_raises(Sanford::InvalidHostError) do
        @host_class.new
      end
    end
  end

  class VersionTest < BaseTest
    desc "version class method"
    setup do
      @host_class.version('v1'){ }
    end

    should "have added a version hash to the versioned_services config" do
      assert_equal({}, @host_class.config.versioned_services["v1"])
    end
  end

  class RunTest < BaseTest
    desc "run method"
    setup do
      @host_class.version('v1') do
        service 'test', 'DummyHost::Multiply'
      end
      @host = @host_class.new({ :port => 12000 })
      @request = Sanford::Protocol::Request.new('v1', 'test', { 'number' => 2 })
      @returned = @host.run(@request)
    end
    subject{ @returned }

    should "have returned the data of calling the `init` and `run` method of the handler" do
      expected_status_code = 200
      expected_data = 2 * @request.params['number']

      assert_equal expected_status_code, subject.first
      assert_equal expected_data, subject.last
    end
  end

  class RunNotFoundTest < BaseTest
    desc "run method with a service and no matching service handler"
    setup do
      @host_class.version('v1') do
        service 'test', 'DummyHost::Echo'
      end
      @host = @host_class.new({ :port => 12000 })
      @request = Sanford::Protocol::Request.new('v4', 'what', {})
    end

    should "raise a Sanford::NotFound exception" do
      assert_raises(Sanford::NotFoundError) do
        @host.run(@request)
      end
    end
  end

  class RunNoHandlerClassTest < BaseTest
    desc "run method with a service handler that doesn't exist"
    setup do
      @host_class.version('v1') do
        service 'test', 'DoesntExist::AtAll'
      end
      @host = @host_class.new({ :port => 12000 })
      @request = Sanford::Protocol::Request.new('v1', 'test', {})
    end

    should "raise a Sanford::NoHandlerClass exception" do
      assert_raises(Sanford::NoHandlerClassError) do
        @host.run(@request)
      end
    end
  end

end
