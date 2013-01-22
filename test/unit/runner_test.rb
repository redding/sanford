require 'assert'

class Sanford::Runner

  class BaseTest < Assert::Context
    desc "Sanford::Runner"
    setup do
      request = Sanford::Protocol::Request.new('v1', 'test', {})
      @runner = Sanford::Runner.new(BasicServiceHandler, request)
    end
    subject{ @runner }

    should have_instance_methods :handler_class, :request, :logger, :run

    should "run the handler and return the response it generates when `run` is called" do
      response = subject.run

      assert_instance_of Sanford::Protocol::Response, response
      assert_equal 200,                     response.code
      assert_equal 'Joe Test',              response.data['name']
      assert_equal 'joe.test@example.com',  response.data['email']
    end

  end

end
