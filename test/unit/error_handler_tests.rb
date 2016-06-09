require 'assert'
require 'sanford/error_handler'

require 'sanford-protocol'
require 'sanford/server_data'

class Sanford::ErrorHandler

  class UnitTests < Assert::Context
    desc "Sanford::ErrorHandler"
    setup do
      @exception   = Factory.exception
      @server_data = Sanford::ServerData.new
      @request     = Sanford::Protocol::Request.new(Factory.string, {
        Factory.string => Factory.string
      })
      @response = Sanford::Protocol::Response.new(Factory.integer)
      @context_hash = {
        :server_data   => @server_data,
        :request       => @request,
        :handler_class => Factory.string,
        :response      => @response
      }

      @handler_class = Sanford::ErrorHandler
    end
    subject{ @handler_class }

  end

  class InitSetupTests < UnitTests
    desc "when init"
    setup do
      # always make sure there are multiple error procs or tests can be false
      # positives
      @error_proc_spies = (1..(Factory.integer(3) + 1)).map{ ErrorProcSpy.new }
      Assert.stub(@server_data, :error_procs){ @error_proc_spies }
    end

  end

  class InitTests < InitSetupTests
    desc "when init"
    setup do
      @handler = @handler_class.new(@exception, @context_hash)
    end
    subject{ @handler }

    should have_readers :exception, :context
    should have_imeths :run

    should "know its exception and context" do
      assert_equal @exception, subject.exception
      exp = Sanford::ErrorContext.new(@context_hash)
      assert_equal exp, subject.context
    end

    should "know its error procs" do
      assert_equal @error_proc_spies.reverse, subject.error_procs
    end

  end

  class RunSetupTests < InitTests
    desc "and run"

  end

  class RunTests < RunSetupTests
    setup do
      @handler.run
    end

    should "call each of its procs" do
      subject.error_procs.each_with_index do |spy, index|
        assert_true spy.called
        assert_equal subject.exception, spy.exception
        assert_equal subject.context,   spy.context
      end
    end

  end

  class RunWithNoResponseFromErrorProcSetupTests < RunSetupTests
    desc "without a response being returned from its error procs"
    setup do
      @error_proc_spies.each{ |s| s.response = nil }
    end

  end

  class RunWithBadMessageErrorTests < RunWithNoResponseFromErrorProcSetupTests
    desc "but with a bad message error exception"
    setup do
      @exception = Factory.exception(Sanford::Protocol::BadMessageError)

      @handler  = @handler_class.new(@exception, @context_hash)
      @response = @handler.run
    end
    subject{ @response }

    should "return a bad request response" do
      exp = Sanford::Protocol::Response.new([400, @exception.message])
      assert_equal exp, subject
    end

  end

  class RunWithInvalidRequestErrorTests < RunWithNoResponseFromErrorProcSetupTests
    desc "but with an invalid request error exception"
    setup do
      @exception = Factory.exception(Sanford::Protocol::Request::InvalidError)

      @handler  = @handler_class.new(@exception, @context_hash)
      @response = @handler.run
    end
    subject{ @response }

    should "return a bad request response" do
      exp = Sanford::Protocol::Response.new([400, @exception.message])
      assert_equal exp, subject
    end

  end

  class RunWithNotFoundErrorTests < RunWithNoResponseFromErrorProcSetupTests
    desc "but with a not found error exception"
    setup do
      @exception = Factory.exception(Sanford::NotFoundError)

      @handler  = @handler_class.new(@exception, @context_hash)
      @response = @handler.run
    end
    subject{ @response }

    should "return a not found response" do
      exp = Sanford::Protocol::Response.new(404)
      assert_equal exp, subject
    end

  end

  class RunWithTimeoutErrorTests < RunWithNoResponseFromErrorProcSetupTests
    desc "but with a timeout error exception"
    setup do
      @exception = Factory.exception(Sanford::Protocol::TimeoutError)

      @handler  = @handler_class.new(@exception, @context_hash)
      @response = @handler.run
    end
    subject{ @response }

    should "return a timeout response" do
      exp = Sanford::Protocol::Response.new(408)
      assert_equal exp, subject
    end

  end

  class RunWithGenericErrorTests < RunWithNoResponseFromErrorProcSetupTests
    desc "but with a generic error"
    setup do
      @exception = Factory.exception

      @handler  = @handler_class.new(@exception, @context_hash)
      @response = @handler.run
    end
    subject{ @response }

    should "return an error response" do
      exp = Sanford::Protocol::Response.new([500, "An unexpected error occurred."])
      assert_equal exp, subject
    end

  end

  class RunWithErrorProcExceptionsTests < InitSetupTests
    desc "and run with error procs that throw exceptions"
    setup do
      @proc_exceptions = @error_proc_spies.reverse.map do |spy|
        exception = Factory.exception(RuntimeError, @error_proc_spies.index(spy).to_s)
        spy.raise_exception = exception
        exception
      end

      @handler  = @handler_class.new(@exception, @context_hash)
      @response = @handler.run
    end
    subject{ @handler }

    should "pass the previously raised exception to the next proc" do
      exp = [@exception] + @proc_exceptions[0..-2]
      assert_equal exp, subject.error_procs.map(&:exception)
    end

    should "set its exception to the last exception thrown by the procs" do
      assert_equal @proc_exceptions.last, subject.exception
    end

    should "return an error response" do
      exp = Sanford::Protocol::Response.new([500, "An unexpected error occurred."])
      assert_equal exp, @response
    end

  end

  class RunWithProtocolResponseFromErrorProcTests < RunSetupTests
    desc "with a protocol response returned from an error proc"
    setup do
      @proc_response = Sanford::Protocol::Response.new(Factory.integer)
      @error_proc_spies.sample.response = @proc_response

      @response = @handler.run
    end
    subject{ @response }

    should "return the protocol response from the error proc" do
      assert_equal @proc_response, subject
    end

  end

  class RunWithResponseCodeFromErrorProcTests < RunSetupTests
    desc "with a response code returned from an error proc"
    setup do
      @response_code = Factory.integer
      @error_proc_spies.sample.response = @response_code

      @response = @handler.run
    end
    subject{ @response }

    should "use the response code to build a response and return it" do
      exp = Sanford::Protocol::Response.new(@response_code)
      assert_equal exp, subject
    end

  end

  class RunWithSymbolFromErrorProcTests < RunSetupTests
    desc "with a response symbol returned from an error proc"
    setup do
      @response_code = [400, 404, 500].sample
      @error_proc_spies.sample.response = @response_code

      @response = @handler.run
    end
    subject{ @response }

    should "use the response symbol to build a response and return it" do
      exp = Sanford::Protocol::Response.new(@response_code)
      assert_equal exp, subject
    end

  end

  class RunWithMultipleResponseFromErrorProcTests < RunSetupTests
    desc "with responses from multiple error procs"
    setup do
      @error_proc_spies.each do |spy|
        spy.response = Sanford::Protocol::Response.new(Factory.integer)
      end

      @response = @handler.run
    end
    subject{ @response }

    should "return the last response from its error procs" do
      assert_equal @error_proc_spies.last.response, subject
    end

  end

  class ErrorContextTests < UnitTests
    desc "ErrorContext"
    setup do
      @context = Sanford::ErrorContext.new(@context_hash)
    end
    subject{ @context }

    should have_readers :server_data
    should have_readers :request, :handler_class, :response

    should "know its attributes" do
      assert_equal @context_hash[:server_data],   subject.server_data
      assert_equal @context_hash[:request],       subject.request
      assert_equal @context_hash[:handler_class], subject.handler_class
      assert_equal @context_hash[:response],      subject.response
    end

    should "know if it equals another context" do
      exp = Sanford::ErrorContext.new(@context_hash)
      assert_equal exp, subject

      exp = Sanford::ErrorContext.new({})
      assert_not_equal exp, subject
    end

  end

  class ErrorProcSpy
    attr_reader :called, :exception, :context
    attr_accessor :response, :raise_exception

    def initialize
      @called = false
    end

    def call(exception, context)
      @called    = true
      @exception = exception
      @context   = context

      raise self.raise_exception if self.raise_exception
      @response
    end
  end

end
