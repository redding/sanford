require 'assert'
require 'sanford/template_source'

require 'sanford/template_engine'

class Sanford::TemplateSource

  class UnitTests < Assert::Context
    desc "Sanford::TemplateSource"
    setup do
      @source_path = File.join(ROOT, 'test/support')
      @source = Sanford::TemplateSource.new(@source_path)
    end
    subject{ @source }

    should have_readers :path, :engines
    should have_imeths :engine

    should "know its path" do
      assert_equal @source_path.to_s, subject.path
    end

  end

  class EngineRegistrationTests < UnitTests
    desc "when registering an engine"
    setup do
      @empty_engine = Class.new(Sanford::TemplateEngine) do
        def render(path, scope); ''; end
      end
    end

    should "allow registering new engines" do
      assert_kind_of Sanford::NullTemplateEngine, subject.engines['empty']
      subject.engine 'empty', @empty_engine
      assert_kind_of @empty_engine, subject.engines['empty']
    end

    should "register with the source path as a default option" do
      subject.engine 'empty', @empty_engine
      exp_opts = { 'source_path' => subject.path }
      assert_equal exp_opts, subject.engines['empty'].opts

      subject.engine 'empty', @empty_engine, 'an' => 'opt'
      exp_opts = {
        'source_path' => subject.path,
        'an' => 'opt'
      }
      assert_equal exp_opts, subject.engines['empty'].opts

      subject.engine 'empty', @empty_engine, 'source_path' => 'something'
      exp_opts = { 'source_path' => 'something' }
      assert_equal exp_opts, subject.engines['empty'].opts
    end

  end

end
