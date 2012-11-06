require 'assert'

class Sanford::ExceptionHandler

  class BaseTest < Assert::Context
    desc "Sanford::Server::ExceptionHandler"
    setup do
      @exception = nil
      begin
        raise "test"
      rescue Exception => @exception
      end
      @logger = Sanford::NullLogger.new
      @exception_handler = Sanford::ExceptionHandler.new(@exception, @logger)
    end
    subject{ @exception_handler }

    should have_instance_methods :exception

    should "have built a 500 Sanford::Response" do
      response = subject.response

      assert_instance_of Sanford::Response, response
      assert_equal 500, response.status.code
      assert_equal "An unexpected error occurred.", response.status.message
    end
  end

  class BadRequestTest < BaseTest
    desc "with a Sanford::BadRequest exception"
    setup do
      @exception = nil
      begin
        raise Sanford::BadRequestError, "test"
      rescue Exception => @exception
      end
      @exception_handler = Sanford::ExceptionHandler.new(@exception, @logger)
    end

    should "have built a 400 Sanford::Response" do
      response = subject.response

      assert_instance_of Sanford::Response, response
      assert_equal 400, response.status.code
      assert_equal "test", response.status.message
    end
  end

  class NotFoundTest < BaseTest
    desc "with a Sanford::NotFound exception"
    setup do
      @exception = nil
      begin
        raise Sanford::NotFoundError, "test"
      rescue Exception => @exception
      end
      @exception_handler = Sanford::ExceptionHandler.new(@exception, @logger)
    end

    should "have built a 404 Sanford::Response" do
      response = subject.response

      assert_instance_of Sanford::Response, response
      assert_equal 404, response.status.code
      assert_equal nil, response.status.message
    end
  end

end
