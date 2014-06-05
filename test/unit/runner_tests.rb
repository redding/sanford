require 'assert'
require 'sanford/runner'

require 'test/support/services'

module Sanford::Runner

  class UnitTests < Assert::Context
    desc "Sanford::Runner"
    setup do
      request = Sanford::Protocol::Request.new('test', {})
      @runner = Sanford::DefaultRunner.new(BasicServiceHandler, request)
    end
    subject{ @runner }

    should have_cmeths :run
    should have_readers :handler_class, :request, :logger, :run

    should "run the handler and return the response it generates when `run` is called" do
      response = subject.run

      assert_instance_of Sanford::Protocol::Response, response
      assert_equal 200,                     response.code
      assert_equal 'Joe Test',              response.data['name']
      assert_equal 'joe.test@example.com',  response.data['email']
    end

    should "be able to build a runner with a handler class and params" do
      response = nil
      assert_nothing_raised do
        response = Sanford::DefaultRunner.run(BasicServiceHandler, {})
      end

      assert_equal 200, response.code
    end

  end

end
