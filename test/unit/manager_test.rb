require 'assert'
require 'ostruct'

class Sanford::Manager

  class BaseTest < Assert::Context
    desc "Sanford::Manager"
    setup do
      @fake_host = OpenStruct.new({ :name => 'fake_host', :pid_dir => 'pid_dir' })
      @manager = Sanford::Manager.new(@fake_host)
    end
    subject{ @manager }

    should have_instance_methods :host, :process_name, :call
    should have_class_methods :call, :load_configuration
  end

end
