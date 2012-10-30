require 'assert'

class Sanford::Server::ExceptionHandler

  class BaseTest < Assert::Context
    desc "Sanford::Server::ExceptionHandler"
    setup do
      @exception = nil
      begin
        raise "test"
      rescue Exception => @exception
      end
      @exception_handler = Sanford::Server::ExceptionHandler.new(@exception)
    end
    subject{ @exception_handler }

    should have_instance_methods :exception, :response

    should "have built a 500 Sanford::Response" do
      assert_instance_of Sanford::Response, subject.response
      assert_equal 500, subject.response.status.code
      assert_equal "An unexpected error occurred.", subject.response.status.message
    end
  end

  class BadRequestTest < BaseTest
    desc "with a Sanford::BadRequest exception"
    setup do
      @exception = nil
      begin
        raise Sanford::BadRequest, "test"
      rescue Exception => @exception
      end
      @exception_handler = Sanford::Server::ExceptionHandler.new(@exception)
    end

    should "have built a 400 Sanford::Response" do
      assert_instance_of Sanford::Response, subject.response
      assert_equal 400, subject.response.status.code
      assert_equal "test", subject.response.status.message
    end
  end

  class NotFoundTest < BaseTest
    desc "with a Sanford::NotFound exception"
    setup do
      @exception = nil
      begin
        raise Sanford::NotFound, "test"
      rescue Exception => @exception
      end
      @exception_handler = Sanford::Server::ExceptionHandler.new(@exception)
    end

    should "have built a 404 Sanford::Response" do
      assert_instance_of Sanford::Response, subject.response
      assert_equal 404, subject.response.status.code
      assert_equal nil, subject.response.status.message
    end
  end

end
