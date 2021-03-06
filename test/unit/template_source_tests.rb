require 'assert'
require 'sanford/template_source'

require 'sanford/logger'
require 'sanford/template_engine'

class Sanford::TemplateSource

  class UnitTests < Assert::Context
    desc "Sanford::TemplateSource"
    subject{ Sanford::TemplateSource }

  end

  class InitTests < Assert::Context
    setup do
      @source_path = ROOT_PATH.join('test/support').to_s
      @logger = 'a-logger'
      @source = Sanford::TemplateSource.new(@source_path, @logger)
    end
    subject{ @source }

    should have_readers :path, :engines
    should have_imeths :engine, :engine_for?, :engine_for_template?
    should have_imeths :render, :partial

    should "know its path" do
      assert_equal @source_path.to_s, subject.path
    end

  end

  class EngineRegistrationTests < InitTests
    desc "when registering an engine"
    setup do
      @test_engine = TestEngine
    end

    should "allow registering new engines" do
      assert_kind_of Sanford::NullTemplateEngine, subject.engines['test']
      subject.engine 'test', @test_engine
      assert_kind_of @test_engine, subject.engines['test']

      assert_true  subject.engine_for?('test')
      assert_false subject.engine_for?(Factory.string)
    end

    should "register with default options" do
      engine_ext = Factory.string
      subject.engine engine_ext, @test_engine
      exp_opts = {
        'source_path' => subject.path,
        'logger'      => @logger,
        'ext'         => engine_ext
      }
      assert_equal exp_opts, subject.engines[engine_ext].opts
      assert_true subject.engine_for?(engine_ext)

      source = Sanford::TemplateSource.new(@source_path)
      source.engine engine_ext, @test_engine
      assert_kind_of Sanford::NullLogger, source.engines[engine_ext].opts['logger']

      custom_opts = { Factory.string => Factory.string }
      subject.engine engine_ext, @test_engine, custom_opts
      exp_opts = {
        'source_path' => subject.path,
        'logger'      => @logger,
        'ext'         => engine_ext
      }.merge(custom_opts)
      assert_equal exp_opts, subject.engines[engine_ext].opts
      assert_true subject.engine_for?(engine_ext)

      custom_opts = {
        'source_path' => Factory.string,
        'logger'      => Factory.string,
        'ext'         => Factory.string
      }
      subject.engine(engine_ext, @test_engine, custom_opts)
      exp_opts = custom_opts.merge('ext' => engine_ext)
      assert_equal exp_opts, subject.engines[engine_ext].opts
      assert_true subject.engine_for?(engine_ext)
    end

    should "know if it has an engine registered for a given template name" do
      assert_false subject.engine_for?(Factory.string)
      assert_false subject.engine_for?('test')
      assert_false subject.engine_for_template?(Factory.string)
      assert_false subject.engine_for_template?('test_template')

      subject.engine 'test', @test_engine
      assert_true subject.engine_for?('test')
      assert_true subject.engine_for_template?('test_template')
    end

  end

  class TemplateTests < InitTests
    setup do
      @source.engine('test', TestEngine)
      @source.engine('json', JsonEngine)
    end

  end

  class RenderTemplateTests < TemplateTests
    desc "when rendering a template"

    should "render a matching template using the configured engine" do
      locals = { :something => Factory.string }
      result = subject.render('test_template', TestServiceHandler, locals)
      assert_equal 'test-engine-render', result

      result = subject.render('test_template.test', TestServiceHandler, locals)
      assert_equal 'test-engine-render', result
    end

    should "use the null template engine when an engine can't be found" do
      assert_raises(ArgumentError) do
        subject.render(Factory.string, TestServiceHandler, {})
      end
    end

    should "complain if the given template name matches multiple templates" do
      # there should be 2 files called "conflict_template" in `test/support`
      # with diff extensions
      assert_raises(ArgumentError) do
        subject.render('conflict_template', TestServiceHandler, {})
      end
    end

  end

  class PartialTemplateTests < TemplateTests
    desc "when rendering a partial template"

    should "render a matching partial template using the configured engine" do
      locals = { :something => Factory.string }
      result = subject.partial('test_template', locals)
      assert_equal 'test-engine-partial', result

      result = subject.partial('test_template.test', locals)
      assert_equal 'test-engine-partial', result
    end

    should "use the null template engine when an engine can't be found" do
      assert_raises(ArgumentError) do
        subject.partial(Factory.string, {})
      end
    end

    should "complain if the given template name matches multiple templates" do
      # there should be 2 files called "conflict_template" in `test/support`
      # with diff extensions
      assert_raises(ArgumentError) do
        subject.partial('conflict_template', {})
      end
    end

  end

  class NullTemplateSourceTests < Assert::Context
    desc "Sanford::NullTemplateSource"
    setup do
      @source = Sanford::NullTemplateSource.new
    end
    subject{ @source }

    should "be a template source" do
      assert_kind_of Sanford::TemplateSource, subject
    end

    should "have an empty path string" do
      assert_equal '', subject.path
    end

    should "optionally take a root path" do
      exp = Factory.path
      source = Sanford::NullTemplateSource.new(exp)
      assert_equal exp, source.path
    end

  end

  class TestEngine < Sanford::TemplateEngine
    def render(path, service_handler, locals)
      'test-engine-render'
    end
    def partial(path, locals)
      'test-engine-partial'
    end
  end

  class JsonEngine < Sanford::TemplateEngine
    def render(path, service_handler, locals)
      'json-engine-render'
    end
    def partial(path, locals)
      'json-engine-partial'
    end
  end

  TestServiceHandler = Class.new

end
