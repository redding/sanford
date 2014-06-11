require 'assert'
require 'sanford/sanford_runner'

require 'sanford/runner'
require 'test/support/service_handlers'

class Sanford::SanfordRunner

  class UnitTests < Assert::Context
    desc "Sanford::SanfordRunner"
    setup do
      @runner_class = Sanford::SanfordRunner
    end
    subject{ @runner_class }

    should "be a Runner" do
      assert_includes Sanford::Runner, subject
    end

    should "be able to build a runner with a handler class and params and run it" do
      response = nil
      assert_nothing_raised do
        response = subject.run(BasicServiceHandler, {})
      end

      assert_equal 200, response.code
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      request = Sanford::Protocol::Request.new('test', {})
      @runner = @runner_class.new(BasicServiceHandler, request)
    end
    subject{ @runner }

    should "run the handler and return the response it generates when `run` is called" do
      response = subject.run

      assert_instance_of Sanford::Protocol::Response, response
      assert_equal 200, response.code
      assert_equal 'Joe Test', response.data['name']
      assert_equal 'joe.test@example.com',  response.data['email']
    end

  end

  # live runner behavior tests are handled via system tests

end
