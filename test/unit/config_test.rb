require 'assert'

module Sanford::Config

  class BaseTest < Assert::Context
    desc "Sanford::Config"
    subject{ Sanford::Config }

    should have_instance_methods :services_config
  end

end
