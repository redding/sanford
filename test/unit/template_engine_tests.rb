require 'assert'
require 'sanford/template_engine'

require 'test/support/factory'

class Sanford::TemplateEngine

  class UnitTests < Assert::Context
    desc "Sanford::TemplateEngine"
    setup do
      @path = Factory.path
      @scope = proc{}
      @engine = Sanford::TemplateEngine.new
    end
    subject{ @engine }

    should have_reader :opts
    should have_imeths :render

    should "default the opts if none given" do
      exp_opts = {}
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
      @engine = Sanford::NullTemplateEngine.new('some' => 'opts')
    end
    subject{ @engine }

    should "be a TemplateEngine" do
      assert_kind_of Sanford::TemplateEngine, subject
    end

    should "know its opts" do
      exp_opts = {'some' => 'opts'}
      assert_equal exp_opts, subject.opts
    end

    should "read and return the given path on `render" do
      exists_file = File.join(ROOT, 'test/support/template.json')
      assert_equal File.read(exists_file), subject.render(exists_file, @scope)
    end

    should "complain if trying to read a template file that does not exist" do
      no_exists_file = '/path/to/file'
      assert_raises ArgumentError do
        subject.render(no_exists_file, @scope)
      end
    end

  end

end
