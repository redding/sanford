require 'assert'

require 'sanford/manager'

class Sanford::Manager

  class BaseTest < Assert::Context
    desc "Sanford::Manager"
    setup do
      @manager = Sanford::Manager.new(TestHost)
    end
    subject{ @manager }

    should have_instance_methods :host_data, :process_name, :call
    should have_class_methods :call
  end

  # Sanford::Manager#call methods are tested in the test/system/managing_test.rb
  # they require mocking the Daemons gem

end
