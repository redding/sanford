require 'assert'
require 'sanford/runner'

require 'sanford-protocol'
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

    should "know its default status code " do
      assert_equal 200, subject::DEFAULT_STATUS_CODE
    end

    should "know its default status msg " do
      assert_equal nil, subject::DEFAULT_STATUS_MSG
    end

    should "know its default data" do
      assert_equal nil, subject::DEFAULT_DATA
    end

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
    should have_imeths :run, :to_response, :status, :data
    should have_imeths :halt, :render, :partial

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

    should "know its `to_response` representation" do
      exp = Sanford::Protocol::Response.new(
        [subject.class::DEFAULT_STATUS_CODE, subject.class::DEFAULT_STATUS_MSG],
        subject.class::DEFAULT_DATA
      )
      assert_equal exp, subject.to_response

      code, msg, data = Factory.integer, Factory.string, Factory.text
      subject.status(code, :message => msg)
      subject.data(data)
      exp = Sanford::Protocol::Response.new([code, msg], data)
      assert_equal exp, subject.to_response
    end

    should "know and set its response status" do
      assert_equal [nil, nil], subject.status

      code, msg = Factory.integer, Factory.string
      subject.status(code, :message => msg)
      assert_equal [code, msg], subject.status
    end

    should "know and set its response data" do
      assert_nil subject.data

      exp = Factory.text
      subject.data exp
      assert_equal exp, subject.data
    end

  end

  class HaltTests < InitTests
    desc "the `halt` method"
    setup do
      @code    = Factory.integer
      @message = Factory.string
      @data    = Factory.string
    end

    should "set response attrs and halt execution" do
      runner = runner_halted_with()
      assert_nil runner.status.first
      assert_nil runner.status.last
      assert_nil runner.data

      runner = runner_halted_with(@code)
      assert_equal @code, runner.status.first
      assert_nil runner.status.last
      assert_nil runner.data

      runner = runner_halted_with(:message => @message)
      assert_nil runner.status.first
      assert_equal @message, runner.status.last
      assert_nil runner.data

      runner = runner_halted_with(:data => @data)
      assert_nil runner.status.first
      assert_nil runner.status.last
      assert_equal @data, runner.data

      runner = runner_halted_with(@code, :message => @message)
      assert_equal @code,    runner.status.first
      assert_equal @message, runner.status.last
      assert_nil runner.data

      runner = runner_halted_with(@code, :data => @data)
      assert_equal @code, runner.status.first
      assert_nil runner.status.last
      assert_equal @data, runner.data

      runner = runner_halted_with({
        :message => @message,
        :data => @data
      })
      assert_nil runner.status.first
      assert_equal @message, runner.status.last
      assert_equal @data,    runner.data

      runner = runner_halted_with(@code, {
        :message => @message,
        :data => @data
      })
      assert_equal @code,    runner.status.first
      assert_equal @message, runner.status.last
      assert_equal @data,    runner.data
    end

    private

    def runner_halted_with(*halt_args)
      @runner_class.new(@handler_class).tap do |runner|
        catch(:halt){ runner.halt(*halt_args) }
      end
    end

  end

  class RenderPartialTests < InitTests
    setup do
      @template_name = Factory.path
      @locals        = { Factory.string => Factory.string }
      @data          = Factory.text

      @source = @runner.template_source
    end

  end

  class RenderTests < RenderPartialTests
    desc "the `render` method"
    setup do
      data                = @data
      @render_called_with = nil
      Assert.stub(@source, :render){ |*args| @render_called_with = args; data }
    end

    should "call to the template source's render method and set the return value as data" do
      subject.render(@template_name, @locals)

      exp = [@template_name, subject.handler, @locals]
      assert_equal exp,   @render_called_with
      assert_equal @data, subject.data
    end

    should "default the locals if none given" do
      subject.render(@template_name)

      exp = [@template_name, subject.handler, {}]
      assert_equal exp, @render_called_with
    end

  end

  class PartialTests < RenderPartialTests
    desc "the `partial` method"
    setup do
      data                 = @data
      @partial_called_with = nil
      Assert.stub(@source, :partial){ |*args| @partial_called_with = args; data }
    end

    should "call to the template source's partial method and set the return value as data" do
      subject.partial(@template_name, @locals)

      exp = [@template_name, @locals]
      assert_equal exp,   @partial_called_with
      assert_equal @data, subject.data
    end

    should "default the locals if none given" do
      subject.partial(@template_name)
      exp = [@template_name, {}]
      assert_equal exp, @partial_called_with
    end

  end

  class TestServiceHandler
    include Sanford::ServiceHandler

  end

end
