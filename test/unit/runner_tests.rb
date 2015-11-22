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
      @runner_class  = Sanford::Runner
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
    should have_readers :logger, :router, :template_source
    should have_readers :request, :params
    should have_imeths :run
    should have_imeths :halt

    should "know its handler class and handler" do
      assert_equal @handler_class, subject.handler_class
      assert_instance_of @handler_class, subject.handler
    end

    should "default its attrs" do
      runner = @runner_class.new(@handler_class)
      assert_kind_of Sanford::NullLogger, runner.logger
      assert_kind_of Sanford::Router, runner.router
      assert_kind_of Sanford::NullTemplateSource, runner.template_source

      assert_nil runner.request

      assert_equal({}, subject.params)
    end

    should "know its attrs" do
      args = {
        :logger          => 'a-logger',
        :router          => 'a-router',
        :template_source => 'a-source',
        :request         => 'a-request',
        :params          => {}
      }

      runner = @runner_class.new(@handler_class, args)

      assert_equal args[:logger],          runner.logger
      assert_equal args[:router],          runner.router
      assert_equal args[:template_source], runner.template_source
      assert_equal args[:request],         runner.request
      assert_equal args[:params],          runner.params
    end

    should "not implement its run method" do
      assert_raises(NotImplementedError){ subject.run }
    end

  end

  class HaltTests < InitTests
    desc "the `halt` method"
    setup do
      @code    = Factory.integer
      @message = Factory.string
      @data    = Factory.string
    end

    should "throw halt with response args" do
      result = runner_halted_with(@code, :message => @message, :data => @data)
      assert_instance_of ResponseArgs, result
      assert_equal [@code, @message], result.status
      assert_equal @data, result.data

      result = runner_halted_with(@code, 'message' => @message, 'data' => @data)
      assert_instance_of ResponseArgs, result
      assert_equal [@code, @message], result.status
      assert_equal @data, result.data
    end

    private

    def runner_halted_with(*halt_args)
      catch(:halt){ @runner_class.new(@handler_class).halt(*halt_args) }
    end

  end

  class RenderTests < InitTests
    desc "the `render` method"
    setup do
      @template_name = Factory.path
      @locals = { Factory.string => Factory.string }
      @render_called_with = nil
      @source = @runner.template_source
      Assert.stub(@source, :render){ |*args| @render_called_with = args }
    end

    should "call to the given source's render method" do
      subject.render(@template_name, @locals)
      exp = [@template_name, subject.handler, @locals]
      assert_equal exp, @render_called_with

      subject.render(@template_name)
      exp = [@template_name, subject.handler, {}]
      assert_equal exp, @render_called_with
    end

  end

  class TestServiceHandler
    include Sanford::ServiceHandler

  end

end
