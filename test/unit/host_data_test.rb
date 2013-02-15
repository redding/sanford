require 'assert'

class Sanford::HostData

  class BaseTest < Assert::Context
    desc "Sanford::HostData"
    setup do
      TestHost.setup_has_been_called = false
      @host_data = Sanford::HostData.new(TestHost)
    end
    teardown do
      TestHost.setup_has_been_called = false
    end
    subject{ @host_data }

    should have_instance_methods :name, :logger, :verbose, :error_proc,
      :handler_class_for

    should "default it's configuration from the service host, but allow overrides" do
      host_data = Sanford::HostData.new(TestHost, :verbose_logging => false)

      assert_equal TestHost.receives_keep_alive, host_data.keep_alive
      assert_equal false, host_data.verbose
    end

    should "ignore nil values passed as overrides" do
      host_data = Sanford::HostData.new(TestHost, :verbose_logging => nil)
      assert_not_nil host_data.verbose
    end

    should "have called the setup proc" do
      assert_equal true, TestHost.setup_has_been_called
    end

    should "constantize a host's handlers" do
      handlers = subject.instance_variable_get("@handlers")
      assert_equal TestHost::Authorized,  handlers['v1']['authorized']
      assert_equal TestHost::Bad,         handlers['v1']['bad']
      assert_equal TestHost::Echo,        handlers['v1']['echo']
      assert_equal TestHost::HaltIt,      handlers['v1']['halt_it']
      assert_equal TestHost::Multiply,    handlers['v1']['multiply']
    end

    should "look up handler classes with #handler_class_for" do
      assert_equal TestHost::Echo, subject.handler_class_for('v1', 'echo')
    end

    should "raise a custom error when handler_class_for is called with an unknown service" do
      assert_raises(Sanford::NotFoundError) do
        subject.handler_class_for('not', 'defined')
      end
    end

    should "raise a custom error when a service is configured with an undefined class" do
      assert_raises(Sanford::NoHandlerClassError) do
        Sanford::HostData.new(UndefinedHandlersHost).setup
      end
    end

  end

end
