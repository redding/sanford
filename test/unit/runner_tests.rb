require 'assert'
require 'sanford/runner'

require 'sanford/logger'
require 'sanford/router'
require 'sanford/template_source'
require 'sanford/service_handler'

class Sanford::Runner

  class UnitTests < Assert::Context
    desc "Sanford::Runner"
    setup do
      @handler_class = TestServiceHandler
      @runner_class = Sanford::Runner
    end
    subject{ @runner_class }

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @runner = @runner_class.new(@handler_class)
    end
    subject{ @runner }

    should have_readers :handler_class, :handler
    should have_readers :request, :params, :logger, :router, :template_source
    should have_imeths :run
    should have_imeths :halt

    should "know its handler class and handler" do
      assert_equal @handler_class, subject.handler_class
      assert_instance_of @handler_class, subject.handler
    end

    should "default its settings" do
      assert_nil subject.request
      assert_equal ::Hash.new, subject.params
      assert_kind_of Sanford::NullLogger, subject.logger
      assert_kind_of Sanford::Router, subject.router
      assert_kind_of Sanford::NullTemplateSource, subject.template_source
    end

    should "not implement its run method" do
      assert_raises(NotImplementedError){ subject.run }
    end

    should "throw halt with response args using `halt`" do
      code = Factory.integer
      message = Factory.string
      data = Factory.string

      result = catch(:halt) do
        subject.halt(code, :message => message, :data => data)
      end
      assert_instance_of ResponseArgs, result
      assert_equal [ code, message ], result.status
      assert_equal data, result.data
    end

    should "accept string keys using `halt`" do
      code = Factory.integer
      message = Factory.string
      data = Factory.string

      result = catch(:halt) do
        subject.halt(code, 'message' => message, 'data' => data)
      end
      assert_instance_of ResponseArgs, result
      assert_equal [ code, message ], result.status
      assert_equal data, result.data
    end

  end

  class TestServiceHandler
    include Sanford::ServiceHandler
  end

end
