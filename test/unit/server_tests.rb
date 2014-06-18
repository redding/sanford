require 'assert'
require 'sanford/server'

require 'ns-options/assert_macros'

module Sanford::Server

  class UnitTests < Assert::Context
    desc "Sanford::Server"
    setup do
      @server_class = Class.new do
        include Sanford::Server
      end
    end
    subject{ @server_class }

    should have_imeths :configuration
    should have_imeths :name, :ip, :port, :pid_file
    should have_imeths :receives_keep_alive

    should "know its configuration" do
      config = subject.configuration
      assert_instance_of Configuration, config
      assert_same config, subject.configuration
    end

    should "allow reading/writing its configuration name" do
      new_name = Factory.string
      subject.name(new_name)
      assert_equal new_name, subject.configuration.name
      assert_equal new_name, subject.name
    end

    should "allow reading/writing its configuration ip" do
      new_ip = Factory.string
      subject.ip(new_ip)
      assert_equal new_ip, subject.configuration.ip
      assert_equal new_ip, subject.ip
    end

    should "allow reading/writing its configuration port" do
      new_port = Factory.integer
      subject.port(new_port)
      assert_equal new_port, subject.configuration.port
      assert_equal new_port, subject.port
    end

    should "allow reading/writing its configuration pid file" do
      new_pid_file = Factory.string
      subject.pid_file(new_pid_file)
      expected = Pathname.new(new_pid_file)
      assert_equal expected, subject.configuration.pid_file
      assert_equal expected, subject.pid_file
    end

    should "allow reading/writing its configuration receives keep alive" do
      new_keep_alive = Factory.boolean
      subject.receives_keep_alive(new_keep_alive)
      assert_equal new_keep_alive, subject.configuration.receives_keep_alive
      assert_equal new_keep_alive, subject.receives_keep_alive
    end

    should "allow reading/writing its configuration verbose logging" do
      new_verbose = Factory.boolean
      subject.verbose_logging(new_verbose)
      assert_equal new_verbose, subject.configuration.verbose_logging
      assert_equal new_verbose, subject.verbose_logging
    end

    should "allow reading/writing its configuration logger" do
      new_logger = Factory.string
      subject.logger(new_logger)
      assert_equal new_logger, subject.configuration.logger
      assert_equal new_logger, subject.logger
    end

    should "allow adding init procs to its configuration" do
      new_init_proc = proc{ Factory.string }
      subject.init(&new_init_proc)
      assert_includes new_init_proc, subject.configuration.init_procs
    end

    should "allow adding error procs to its configuration" do
      new_error_proc = proc{ Factory.string }
      subject.error(&new_error_proc)
      assert_includes new_error_proc, subject.configuration.error_procs
    end

    should "allow reading/writing its configuration router" do
      new_router = Factory.string
      subject.router(new_router)
      assert_equal new_router, subject.configuration.router
      assert_equal new_router, subject.router
    end

    should "allow setting the configuration template source" do
      new_path = Factory.string
      yielded = nil
      subject.set_template_source(new_path){ |s| yielded = s }
      assert_equal new_path, subject.configuration.template_source.path
      assert_equal subject.configuration.template_source, yielded
    end

  end

  class ConfigurationTests < UnitTests
    include NsOptions::AssertMacros

    desc "Configuration"
    setup do
      @configuration = Configuration.new
    end
    subject{ @configuration }

    should have_options :name, :ip, :port, :pid_file
    should have_options :receives_keep_alive
    should have_options :verbose_logging, :logger
    should have_accessors :init_procs, :error_procs
    should have_accessors :router
    should have_readers :template_source
    should have_imeths :set_template_source
    should have_imeths :routes
    should have_imeths :valid?, :validate!

    should "be an ns-options proxy" do
      assert_includes NsOptions::Proxy, subject.class
    end

    should "default its options" do
      assert_nil subject.name
      assert_equal '0.0.0.0', subject.ip
      assert_nil subject.port
      assert_nil subject.pid_file

      assert_false subject.receives_keep_alive

      assert_true subject.verbose_logging
      assert_instance_of Sanford::NullLogger, subject.logger

      assert_equal [], subject.init_procs
      assert_equal [], subject.error_procs

      assert_instance_of Sanford::NullTemplateSource, subject.template_source
      assert_instance_of Sanford::Router, subject.router
      assert_empty subject.router.routes
    end

    should "not be valid by default" do
      assert_false subject.valid?
    end

    should "allow setting its template source" do
      new_path = Factory.string
      yielded = nil
      subject.set_template_source(new_path){ |s| yielded = s }
      assert_instance_of Sanford::TemplateSource, subject.template_source
      assert_equal new_path, subject.template_source.path
      assert_equal subject.template_source, yielded
    end

    should "allow only setting the template source path" do
      new_path = Factory.string
      subject.set_template_source(new_path)
      assert_instance_of Sanford::TemplateSource, subject.template_source
      assert_equal new_path, subject.template_source.path
    end

    should "know its routes" do
      assert_equal subject.router.routes, subject.routes
      subject.router.service(Factory.string, TestHandler.to_s)
      assert_equal subject.router.routes, subject.routes
    end

    should "call its init procs when validated" do
      called = false
      subject.init_procs << proc{ called = true }
      subject.validate!
      assert_true called
    end

    should "validate its routes when validated" do
      subject.router.service(Factory.string, TestHandler.to_s)
      subject.routes.each{ |route| assert_nil route.handler_class }
      subject.validate!
      subject.routes.each{ |route| assert_not_nil route.handler_class }
    end

    should "be valid after being validated" do
      assert_false subject.valid?
      subject.validate!
      assert_true subject.valid?
    end

    should "only be able to be validated once" do
      called = 0
      subject.init_procs << proc{ called += 1 }
      subject.validate!
      assert_equal 1, called
      subject.validate!
      assert_equal 1, called
    end

  end

  TestHandler = Class.new

end
