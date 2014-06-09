require 'assert'
require 'sanford/config'

require 'ns-options/proxy'

module Sanford::Config

  class UnitTests < Assert::Context
    desc "Sanford::Config"
    subject{ Sanford::Config }

    should have_imeths :services_file, :logger, :runner

    should "be an NsOptions::Proxy" do
      assert_includes NsOptions::Proxy, subject
    end

  end

end
