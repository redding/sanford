require 'assert'
require 'sanford/host_data'

require 'test/support/services'

class Sanford::HostData

  class UnitTests < Assert::Context
    desc "Sanford::HostData"
    setup do
      TestHost.init_has_been_called = false
      @host_data = Sanford::HostData.new(TestHost)
    end
    teardown do
      TestHost.init_has_been_called = false
    end
    subject{ @host_data }

    should have_readers :name, :logger, :verbose, :keep_alive, :runner, :error_procs
    should have_imeths :handler_class_for, :run

    should "call the init procs" do
      assert_equal true, TestHost.init_has_been_called
    end

    should "default its attrs from the host configuration" do
      assert_equal TestHost.configuration.name,                subject.name
      assert_equal TestHost.configuration.logger.class,        subject.logger.class
      assert_equal TestHost.configuration.verbose_logging,     subject.verbose
      assert_equal TestHost.configuration.receives_keep_alive, subject.keep_alive
      assert_equal TestHost.configuration.runner.class,        subject.runner.class
      assert_equal TestHost.configuration.error_procs,         subject.error_procs
    end

    should "allow overriding host configuration attrs" do
      host_data = Sanford::HostData.new(TestHost, :verbose_logging => false)

      assert_false host_data.verbose
      assert_equal TestHost.receives_keep_alive, host_data.keep_alive
    end

    should "ignore nil values passed as overrides" do
      host_data = Sanford::HostData.new(TestHost, :verbose_logging => nil)
      assert_not_nil host_data.verbose
    end

    should "constantize a host's handlers" do
      handlers = subject.instance_variable_get("@handlers")
      assert_equal TestHost::Authorized, handlers['authorized']
      assert_equal TestHost::Bad,        handlers['bad']
      assert_equal TestHost::Echo,       handlers['echo']
      assert_equal TestHost::HaltIt,     handlers['halt_it']
      assert_equal TestHost::Multiply,   handlers['multiply']
    end

    should "look up handler classes with #handler_class_for" do
      assert_equal TestHost::Echo, subject.handler_class_for('echo')
    end

    should "raise a custom error when handler_class_for is called with an unknown service" do
      assert_raises(Sanford::NotFoundError) do
        subject.handler_class_for('not_defined')
      end
    end

    should "raise a custom error when a service is configured with an undefined class" do
      assert_raises(Sanford::NoHandlerClassError) do
        Sanford::HostData.new(UndefinedHandlersHost).setup
      end
    end

  end

end
