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

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @request = Sanford::Protocol::Request.new('test', {})
      @runner = @runner_class.new(BasicServiceHandler, @request)
    end
    subject{ @runner }

    should "run the handler and return the response it generates when run" do
      response = subject.run

      assert_instance_of Sanford::Protocol::Response, response
      assert_equal 200, response.code
      assert_equal 'Joe Test', response.data['name']
      assert_equal 'joe.test@example.com',  response.data['email']
    end

  end

  class CallbackTests < InitTests
    setup do
      @runner = @runner_class.new(FlagServiceHandler, @request)
    end

    should "call handler `before` and `after` callbacks when run" do
      subject.run

      assert_true subject.handler.before_called
      assert_true subject.handler.after_called
    end

  end

  # live runner behavior tests are handled via system tests

end
