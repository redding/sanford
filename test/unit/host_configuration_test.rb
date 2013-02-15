require 'assert'

class Sanford::Host::Configuration

  class BaseTest < Assert::Context
    desc "Sanford::Host::Configuration"
    setup do
      @configuration = Sanford::Host::Configuration.new(EmptyHost.instance)
    end
    subject{ @configuration }

    should have_instance_methods :name, :ip, :port, :pid_file, :logger,
      :verbose_logging, :logger, :error_proc

    should "default name to the class name of the host" do
      assert_equal 'EmptyHost', subject.name
    end

    should "default ip to 0.0.0.0" do
      assert_equal '0.0.0.0', subject.ip
    end

    should "not default the port" do
      assert_nil subject.port
    end

    should "default logger to a null logger" do
      assert_instance_of Sanford::NullLogger, subject.logger
    end

    should "default verbose_logging to true" do
      assert_equal true, subject.verbose_logging
    end

  end

end
