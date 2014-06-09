require 'assert'
require 'sanford/config'

require 'ns-options/assert_macros'
require 'ns-options/proxy'
require 'sanford/logger'
require 'sanford/runner'
require 'test/support/factory'

class Sanford::Config

  class UnitTests < Assert::Context
    include NsOptions::AssertMacros

    desc "Sanford::Config"
    setup do
      @config = Sanford::Config.new
    end
    subject{ @config }

    should have_options :services_file, :logger, :runner
    should have_readers :template_source
    should have_imeths :set_template_source

    should "be an NsOptions::Proxy" do
      assert_includes NsOptions::Proxy, subject.class
    end

    should "default its services file" do
      exp = Pathname.new(ENV['SANFORD_SERVICES_FILE'])
      assert_equal exp, subject.services_file
    end

    should "default its logger to a NullLogger" do
      assert_kind_of Sanford::NullLogger, subject.logger
    end

    should "default its runner to a DefaultRunner" do
      assert_equal Sanford::DefaultRunner, subject.runner
    end

    should "have no template source by default" do
      assert_nil subject.template_source
    end

    should "set a new template source" do
      path = '/path/to/app/assets'
      block_called = false
      subject.set_template_source(path) { |s| block_called = true}

      assert_not_nil subject.template_source
      assert_kind_of Sanford::TemplateSource, subject.template_source
      assert_equal path, subject.template_source.path
      assert_true block_called
    end

  end

end
