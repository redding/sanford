require 'assert'

module Sanford::Host

  class BaseTest < Assert::Context
    desc "Sanford::Host"
    setup do
      @configuration = MyHost.configuration.to_hash
    end
    teardown do
      MyHost.configuration.apply(@configuration)
    end
    subject{ MyHost.instance }

    should have_instance_methods :configuration, :name, :ip, :port, :pid_dir, :logger,
      :verbose_logging, :exception_handler, :version, :versioned_services

    should "get and set it's configuration options with their matching methods" do
      subject.name 'my_awesome_host'

      assert_equal 'my_awesome_host',           subject.name
      assert_equal subject.configuration.port,  subject.port


    end

    should "add a version group with #version" do
      subject.version('v1'){ }

      assert_equal({}, subject.versioned_services["v1"])
    end

  end

  class ClassMethodsTest < Assert::Context
    desc "Sanford::Host class"
    subject{ MyHost }

    should "proxy it's method to it's instance" do
      assert_equal subject.instance.name, subject.name
      assert subject.respond_to?(:pid_dir)
    end

    should "have registered the class with sanford's known hosts" do
      assert_includes subject, Sanford.hosts
    end

  end

end
