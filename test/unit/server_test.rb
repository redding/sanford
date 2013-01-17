require 'assert'

require 'sanford/server'
require 'sanford/manager'

class Sanford::Server

  class BaseTest < Assert::Context
    desc "Sanford::Server"
    setup do
      @server = Sanford::Server.new(TestHost)
    end
    subject{ @server }

    should "include DatTCP::Server" do
      assert_includes DatTCP::Server, subject.class.included_modules
    end

    should "use the service host's ip and port" do
      assert_equal TestHost.ip,   subject.host
      assert_equal TestHost.port, subject.port
    end

  end

  # Sanford::Server#serve is tested in test/system/request_handling_test.rb,
  # it requires multiple parts of Sanford and basically tests a large portion of
  # the entire system

end
