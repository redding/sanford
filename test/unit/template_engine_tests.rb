require 'assert'
require 'sanford/template_engine'

require 'pathname'
require 'sanford/logger'
require 'test/support/factory'

class Sanford::TemplateEngine

  class UnitTests < Assert::Context
    desc "Sanford::TemplateEngine"
    setup do
      @source_path = Factory.path
      @path = Factory.path
      @service_handler = 'a-service-handler'
      @locals = {}
      @engine = Sanford::TemplateEngine.new('some' => 'opts')
    end
    subject{ @engine }

    should have_readers :source_path, :logger, :opts
    should have_imeths :render, :partial

    should "default its source path" do
      assert_equal Pathname.new(nil.to_s), subject.source_path
    end

    should "allow custom source paths" do
      engine = Sanford::TemplateEngine.new('source_path' => @source_path)
      assert_equal Pathname.new(@source_path.to_s), engine.source_path
    end

    should "default its logger" do
      assert_instance_of Sanford::NullLogger, subject.logger
    end

    should "allow custom loggers" do
      logger = 'a-logger'
      engine = Sanford::TemplateEngine.new('logger' => logger)
      assert_equal logger, engine.logger
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
        subject.render(@path, @service_handler, @locals)
      end
    end

    should "raise NotImplementedError on `partial`" do
      assert_raises NotImplementedError do
        subject.partial(@path, @locals)
      end
    end

  end

  class NullTemplateEngineTests < Assert::Context
    desc "Sanford::NullTemplateEngine"
    setup do
      @engine = Sanford::NullTemplateEngine.new('source_path' => ROOT_PATH.to_s)
    end
    subject{ @engine }

    should "be a TemplateEngine" do
      assert_kind_of Sanford::TemplateEngine, subject
    end

    should "read and return the given path in its source path" do
      exists_file = ['test/support/template', 'test/support/template.erb'].sample
      exp = File.read(Dir.glob("#{subject.source_path.join(exists_file)}*").first)
      assert_equal exp, subject.render(exists_file, @service_handler, @locals)
      assert_equal exp, subject.partial(exists_file, @locals)
    end

    should "complain if given a path that matches multiple files" do
      conflict_file = 'test/support/conflict_template'
      assert_raises ArgumentError do
        subject.render(conflict_file, @service_handler, @locals)
      end
      assert_raises ArgumentError do
        subject.partial(conflict_file, @locals)
      end
    end

    should "complain if given a path that does not exist in its source path" do
      no_exists_file = '/does/not/exists'
      assert_raises ArgumentError do
        subject.render(no_exists_file, @service_handler, @locals)
      end
      assert_raises ArgumentError do
        subject.partial(no_exists_file, @locals)
      end
    end

  end

end
