require 'assert'

class Sanford::Server

  class BaseTest < Assert::Context
    desc "Sanford::Server"
    setup do
      @service_host = DummyHost.new
      @server = Sanford::Server.new(@service_host)
    end
    subject{ @server }

    should "include DatTCP::Server" do
      assert_includes DatTCP::Server, subject.class.included_modules
    end
  end

  # Sanford::Server#serve is tested in test/system/request_handling_test.rb,
  # it requires multiple parts of Sanford and basically tests a large portion of
  # the entire system

end
