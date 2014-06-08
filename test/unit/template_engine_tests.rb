require 'assert'
require 'sanford/template_engine'

require 'pathname'
require 'test/support/factory'

class Sanford::TemplateEngine

  class UnitTests < Assert::Context
    desc "Sanford::TemplateEngine"
    setup do
      @source_path = Factory.path
      @path = Factory.path
      @scope = proc{}
      @engine = Sanford::TemplateEngine.new('some' => 'opts')
    end
    subject{ @engine }

    should have_readers :source_path, :opts
    should have_imeths :render

    should "default its source path" do
      assert_equal Pathname.new(nil.to_s), subject.source_path
    end

    should "allow custom source paths" do
      engine = Sanford::TemplateEngine.new('source_path' => @source_path)
      assert_equal Pathname.new(@source_path.to_s), engine.source_path
    end

    should "default the opts if none given" do
      exp_opts = {}
      assert_equal exp_opts, Sanford::TemplateEngine.new.opts
    end

    should "allow custom opts" do
      exp_opts = {'some' => 'opts'}
      assert_equal exp_opts, subject.opts
    end

    should "raise NotImplementedError on `render`" do
      assert_raises NotImplementedError do
        subject.render(@path, @scope)
      end
    end

  end

  class NullTemplateEngineTests < Assert::Context
    desc "Sanford::NullTemplateEngine"
    setup do
      @engine = Sanford::NullTemplateEngine.new('source_path' => ROOT)
    end
    subject{ @engine }

    should "be a TemplateEngine" do
      assert_kind_of Sanford::TemplateEngine, subject
    end

    should "read and return the given path in its source path on `render" do
      exists_file = 'test/support/template.json'
      exp = File.read(subject.source_path.join(exists_file).to_s)
      assert_equal exp, subject.render(exists_file, @scope)
    end

    should "complain if given a path that does not exist in its source path" do
      no_exists_file = '/does/not/exists'
      assert_raises ArgumentError do
        subject.render(no_exists_file, @scope)
      end
    end

  end

end
