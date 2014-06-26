require 'assert'
require 'sanford/service_handler'

require 'sanford/template_engine'
require 'sanford/template_source'

module Sanford::ServiceHandler

  class UnitTests < Assert::Context
    desc "Sanford::ServiceHandler"
    setup do
      @handler_class = Class.new{ include Sanford::ServiceHandler }
    end
    subject{ @handler_class }

    should have_imeths :before_callbacks, :after_callbacks
    should have_imeths :before_init_callbacks, :after_init_callbacks
    should have_imeths :before_run_callbacks,  :after_run_callbacks
    should have_imeths :before, :after
    should have_imeths :before_init, :after_init
    should have_imeths :before_run,  :after_run
    should have_imeths :prepend_before, :prepend_after
    should have_imeths :prepend_before_init, :prepend_after_init
    should have_imeths :prepend_before_run,  :prepend_after_run

    should "return an empty array by default using `before_callbacks`" do
      assert_equal [], subject.before_callbacks
    end

    should "return an empty array by default using `after_callbacks`" do
      assert_equal [], subject.after_callbacks
    end

    should "return an empty array by default using `before_init_callbacks`" do
      assert_equal [], subject.before_init_callbacks
    end

    should "return an empty array by default using `after_init_callbacks`" do
      assert_equal [], subject.after_init_callbacks
    end

    should "return an empty array by default using `before_run_callbacks`" do
      assert_equal [], subject.before_run_callbacks
    end

    should "return an empty array by default using `after_run_callbacks`" do
      assert_equal [], subject.after_run_callbacks
    end

    should "append a block to the before callbacks using `before`" do
      subject.before_callbacks << proc{ Factory.string }
      block = Proc.new{ Factory.string }
      subject.before(&block)
      assert_equal block, subject.before_callbacks.last
    end

    should "append a block to the after callbacks using `after`" do
      subject.after_callbacks << proc{ Factory.string }
      block = Proc.new{ Factory.string }
      subject.after(&block)
      assert_equal block, subject.after_callbacks.last
    end

    should "append a block to the before init callbacks using `before_init`" do
      subject.before_init_callbacks << proc{ Factory.string }
      block = Proc.new{ Factory.string }
      subject.before_init(&block)
      assert_equal block, subject.before_init_callbacks.last
    end

    should "append a block to the after init callbacks using `after_init`" do
      subject.after_init_callbacks << proc{ Factory.string }
      block = Proc.new{ Factory.string }
      subject.after_init(&block)
      assert_equal block, subject.after_init_callbacks.last
    end

    should "append a block to the before run callbacks using `before_run`" do
      subject.before_run_callbacks << proc{ Factory.string }
      block = Proc.new{ Factory.string }
      subject.before_run(&block)
      assert_equal block, subject.before_run_callbacks.last
    end

    should "append a block to the after run callbacks using `after_run`" do
      subject.after_run_callbacks << proc{ Factory.string }
      block = Proc.new{ Factory.string }
      subject.after_run(&block)
      assert_equal block, subject.after_run_callbacks.last
    end

    should "prepend a block to the before callbacks using `prepend_before`" do
      subject.before_callbacks << proc{ Factory.string }
      block = Proc.new{ Factory.string }
      subject.prepend_before(&block)
      assert_equal block, subject.before_callbacks.first
    end

    should "prepend a block to the after callbacks using `prepend_after`" do
      subject.after_callbacks << proc{ Factory.string }
      block = Proc.new{ Factory.string }
      subject.prepend_after(&block)
      assert_equal block, subject.after_callbacks.first
    end

    should "prepend a block to the before init callbacks using `prepend_before_init`" do
      subject.before_init_callbacks << proc{ Factory.string }
      block = Proc.new{ Factory.string }
      subject.prepend_before_init(&block)
      assert_equal block, subject.before_init_callbacks.first
    end

    should "prepend a block to the after init callbacks using `prepend_after_init`" do
      subject.after_init_callbacks << proc{ Factory.string }
      block = Proc.new{ Factory.string }
      subject.prepend_after_init(&block)
      assert_equal block, subject.after_init_callbacks.first
    end

    should "prepend a block to the before run callbacks using `prepend_before_run`" do
      subject.before_run_callbacks << proc{ Factory.string }
      block = Proc.new{ Factory.string }
      subject.prepend_before_run(&block)
      assert_equal block, subject.before_run_callbacks.first
    end

    should "prepend a block to the after run callbacks using `prepend_after_run`" do
      subject.after_run_callbacks << proc{ Factory.string }
      block = Proc.new{ Factory.string }
      subject.prepend_after_run(&block)
      assert_equal block, subject.after_run_callbacks.first
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @runner = FakeRunner.new
      @handler = TestServiceHandler.new(@runner)
    end
    subject{ @handler }

    should have_imeths :init, :init!, :run, :run!

    should "know its request, params and logger" do
      assert_equal @runner.request, subject.request
      assert_equal @runner.params, subject.params
      assert_equal @runner.logger, subject.logger
    end

    should "call `init!` and its before/after init callbacks using `init`" do
      subject.init
      assert_equal 1, subject.first_before_init_call_order
      assert_equal 2, subject.second_before_init_call_order
      assert_equal 3, subject.init_call_order
      assert_equal 4, subject.first_after_init_call_order
      assert_equal 5, subject.second_after_init_call_order
    end

    should "call `run!` and its before/after run callbacks using `run`" do
      subject.run
      assert_equal 1, subject.first_before_run_call_order
      assert_equal 2, subject.second_before_run_call_order
      assert_equal 3, subject.run_call_order
      assert_equal 4, subject.first_after_run_call_order
      assert_equal 5, subject.second_after_run_call_order
    end

    should "have a custom inspect" do
      reference = '0x0%x' % (subject.object_id << 1)
      expected = "#<#{subject.class}:#{reference} " \
                 "@request=#{subject.request.inspect}>"
      assert_equal expected, subject.inspect
    end

    should "demeter its runner's halt" do
      code = Factory.integer
      result = subject.halt(code)
      assert_includes [ code ], @runner.halt_calls
    end

    should "use the runner template source to render the template by default" do
      path = Factory.file_path
      locals = { 'something' => Factory.string }
      result = subject.render(path, 'locals' => locals)
      assert_equal [ path, TestServiceHandler.to_s, locals ], result
    end

    should "default its locals to an empty hash using `render`" do
      path = Factory.file_path
      result = subject.render(path)
      assert_equal [ path, TestServiceHandler.to_s, {} ], result
    end

    should "allow passing a source to its options using `render`" do
      path = Factory.file_path
      source_class = Class.new do
        def render(path, service_handler, locals); path; end
      end
      result = subject.render(path, 'source' => source_class.new)
      assert_equal path, result
    end

    should "raise a not implemented error when `run!` by default" do
      assert_raises(NotImplementedError){ @handler_class.new(@runner).run! }
    end

  end

  class TestServiceHandler
    include Sanford::ServiceHandler

    attr_reader :first_before_init_call_order, :second_before_init_call_order
    attr_reader :first_after_init_call_order, :second_after_init_call_order
    attr_reader :first_before_run_call_order, :second_before_run_call_order
    attr_reader :first_after_run_call_order, :second_after_run_call_order
    attr_reader :init_call_order, :run_call_order

    # these methods are made public so they can be tested, they are being tested
    # because they are used by classes that mixin this, essentially they are
    # "public" to classes that use the mixin
    public :render, :halt, :request, :params, :logger

    before_init{ @first_before_init_call_order = next_call_order }
    before_init{ @second_before_init_call_order = next_call_order }

    after_init{ @first_after_init_call_order = next_call_order }
    after_init{ @second_after_init_call_order = next_call_order }

    before_run{ @first_before_run_call_order = next_call_order }
    before_run{ @second_before_run_call_order = next_call_order }

    after_run{ @first_after_run_call_order = next_call_order }
    after_run{ @second_after_run_call_order = next_call_order }

    def init!
      @init_call_order = next_call_order
    end

    def run!
      @run_call_order = next_call_order
    end

    private

    def next_call_order
      @order ||= 0
      @order += 1
    end
  end

  class FakeRunner
    attr_accessor :request, :params, :logger, :template_source
    attr_reader :halt_calls

    def initialize
      @request = Factory.string
      @params = Factory.string
      @logger = Factory.string
      @template_source = FakeTemplateSource.new
    end

    def halt(*args)
      @halt_calls ||= []
      @halt_calls << args
    end
  end

  class FakeTemplateSource
    def render(path, service_handler, locals)
      [path.to_s, service_handler.class.to_s, locals]
    end
  end

end
