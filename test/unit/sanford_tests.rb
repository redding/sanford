require 'assert'
require 'sanford'

require 'sanford/config'

module Sanford

  class UnitTests < Assert::Context
    desc "Sanford"
    subject{ Sanford }

    should have_imeths :config, :configure, :init, :register, :hosts

    should "return a `Config` instance with the `config` method" do
      assert_kind_of Sanford::Config, subject.config
    end

  end

end
