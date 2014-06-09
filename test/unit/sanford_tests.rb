require 'assert'
require 'sanford'

module Sanford

  class UnitTests < Assert::Context
    desc "Sanford"
    subject{ Sanford }

    should have_imeths :config, :configure, :init, :register, :hosts

  end

end
