require 'assert'

require 'sanford/manager'

class Sanford::Manager::Options

  class BaseTest < Assert::Context
    desc "Sanford::Manager::Options"
    setup do
      @options = Sanford::Manager::Options.new(MyHost)
    end
    subject{ @options }

    should have_instance_methods :hash

    should "be a kind of OpenStruct" do
      assert_kind_of OpenStruct, subject
    end

    should "default it's values based on the service host's configuration but allow passing " \
     "overrides for options" do
      options = Sanford::Manager::Options.new(MyHost, :ip => '1.2.3.4', :port => 12345)

      assert_equal 'my_host', options.name
      assert_equal '1.2.3.4', options.ip
      assert_equal 12345,     options.port
    end

    should "ignore nil values passed as overrides" do
      options = Sanford::Manager::Options.new(MyHost, :ip => nil)

      assert_not_nil options.ip
    end

  end

end
