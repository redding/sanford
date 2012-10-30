require 'assert'
require 'ostruct'

class Sanford::Manager

  class BaseTest < Assert::Context
    desc "Sanford::Manager"
    setup do
      @dummy_host = DummyHost
      @manager = Sanford::Manager.new(@dummy_host)
    end
    subject{ @manager }

    should have_instance_methods :host, :process_name, :call
    should have_class_methods :call
  end

  # Sanford::Manager#call methods are tested in the test/system/managing_test.rb
  # they require mocking the Daemons gem

end
