require 'assert'
require 'sanford/host'

require 'sanford/logger'
require 'sanford/runner'

module Sanford::Host

  class UnitTests < Assert::Context
    desc "Sanford::Host"
    setup do
      @host_class = Class.new{ include Sanford::Host }
    end
    subject{ @host_class.instance }

    should have_readers :configuration, :services
    should have_imeths :name, :ip, :port, :pid_file, :logger, :verbose_logging
    should have_imeths :runner, :error, :init, :service_handler_ns, :service

    should "know its configuration" do
      assert_kind_of Configuration, subject.configuration
    end

    should "have no services by default" do
      assert_empty subject.services
    end

    should "get/set its configuration options" do
      subject.name 'my_awesome_host'
      assert_equal 'my_awesome_host', subject.name
      assert_equal subject.name, subject.configuration.name

      subject.ip '127.0.0.1'
      assert_equal '127.0.0.1', subject.ip
      assert_equal subject.ip, subject.configuration.ip

      subject.port '10100'
      assert_equal 10100, subject.port
      assert_equal subject.port, subject.configuration.port

      subject.pid_file '/path/to/file'
      assert_equal Pathname.new('/path/to/file'), subject.pid_file
      assert_equal subject.pid_file, subject.configuration.pid_file

      logger = Sanford::NullLogger.new
      subject.logger logger
      assert_equal logger, subject.logger
      assert_equal subject.logger, subject.configuration.logger

      subject.verbose_logging false
      assert_equal false, subject.verbose_logging
      assert_equal subject.verbose_logging, subject.configuration.verbose_logging

      subject.receives_keep_alive true
      assert_equal true, subject.receives_keep_alive
      assert_equal subject.receives_keep_alive, subject.configuration.receives_keep_alive

      subject.runner Sanford::DefaultRunner
      assert_equal Sanford::DefaultRunner, subject.runner
      assert_equal subject.runner, subject.configuration.runner
    end

    should "add error procs to the configuration" do
      assert_empty subject.configuration.error_procs
      subject.error &proc{}
      assert_not_empty subject.configuration.error_procs
    end

    should "add init procs to the configuration" do
      assert_empty subject.configuration.init_procs
      subject.init &proc{}
      assert_not_empty subject.configuration.init_procs
    end

    should "get/set its service_handler_ns" do
      assert_nil subject.service_handler_ns
      subject.service_handler_ns 'a-ns'
      assert_equal 'a-ns', subject.service_handler_ns
    end

    should "add services" do
      subject.service_handler_ns 'MyNamespace'
      subject.service('test', 'MyServiceHandler')

      assert_equal 'MyNamespace::MyServiceHandler', subject.services['test']
    end

    should "force string names when adding services" do
      subject.service(:another_service, 'MyServiceHandler')
      assert_nil subject.services[:another_service]
      assert_equal 'MyServiceHandler', subject.services['another_service']
    end

    should "ignore a namespace when a service class has leading colons" do
      subject.service_handler_ns 'MyNamespace'
      subject.service('test', '::MyServiceHandler')

      assert_equal '::MyServiceHandler', subject.services['test']
    end

  end

  class ClassMethodsTests < UnitTests
    desc "class"
    subject{ @host_class }

    should "proxy its method to its instance" do
      assert_equal subject.instance.name, subject.name
      assert subject.respond_to?(:pid_file)
    end

    should "have registered the class with sanford's known hosts" do
      assert_includes subject, Sanford.hosts
    end

  end

  class ConfigurationTests < UnitTests
    desc "Configuration"
    setup do
      @configuration = Configuration.new(@host_class.instance)
    end
    subject{ @configuration }

    should have_imeths :name, :ip, :port, :pid_file, :logger, :verbose_logging
    should have_imeths :receives_keep_alive, :runner, :error_procs, :init_procs

    should "default name to the class name of the host" do
      assert_equal @host_class.name, subject.name
    end

    should "default its other attrs" do
      assert_equal '0.0.0.0', subject.ip
      assert_nil subject.port
      assert_nil subject.pid_file
      assert_equal Sanford.config.logger.class, subject.logger.class
      assert_true  subject.verbose_logging
      assert_false subject.receives_keep_alive
      assert_equal Sanford.config.runner, subject.runner
      assert_empty subject.error_procs
      assert_empty subject.init_procs
    end

  end

end
