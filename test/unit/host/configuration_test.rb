require 'assert'

class Sanford::Host::Configuration

  class BaseTest < Assert::Context
    desc "Sanford::Host::Configuration"
    setup do
      @configuration = Sanford::Host::Configuration.new
    end
    subject{ @configuration }

    should have_instance_methods :host, :port, :pid_dir, :logging, :logger

    should "be an ns-options proxy" do
      assert_includes NsOptions::Proxy, subject.class.included_modules
    end
    should "allow setting host and port with #bind" do
      subject.bind 'test.local:12345'

      assert_equal 'test.local', subject.host
      assert_equal 12345, subject.port
    end
  end

end
