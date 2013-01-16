require 'assert'

require 'sanford/manager'

class Sanford::Manager

  class BaseTest < Assert::Context
    desc "Sanford::Manager"
    setup do
      @manager = Sanford::Manager.new(TestHost)
    end
    subject{ @manager }

    should have_instance_methods :service_host, :process_name, :options, :call
    should have_class_methods :call
  end

  class InvalidServerOptionsTest < BaseTest
    desc "invalid server options"

    should "raise a custom exception" do
      assert_raises(Sanford::InvalidServerOptionsError) do
        Sanford::Manager.new(InvalidHost)
      end
    end

  end

  # Sanford::Manager#call methods are tested in the test/system/managing_test.rb
  # they require mocking the Daemons gem

end
