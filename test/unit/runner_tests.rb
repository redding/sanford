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
      source = FakeTemplateSource.new
      @runner = @runner_class.new(@handler_class, :template_source => source)
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
      runner = @runner_class.new(@handler_class)
      assert_nil runner.request
      assert_equal ::Hash.new, runner.params
      assert_kind_of Sanford::NullLogger, runner.logger
      assert_kind_of Sanford::Router, runner.router
      assert_kind_of Sanford::NullTemplateSource, runner.template_source
    end

    should "not implement its run method" do
      assert_raises(NotImplementedError){ subject.run }
    end

    should "use the template source to render" do
      path = 'template.json'
      locals = { 'something' => Factory.string }
      exp = subject.template_source.render(path, subject.handler, locals)
      assert_equal exp, subject.render(path, locals)
    end

    should "default its locals to an empty hash when rendering" do
      path = Factory.file_path
      exp = subject.template_source.render(path, subject.handler, {})
      assert_equal exp, subject.render(path)
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

  class FakeTemplateSource
    def render(path, service_handler, locals)
      [path.to_s, service_handler.class.to_s, locals]
    end
  end

end
