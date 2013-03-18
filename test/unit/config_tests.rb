require 'assert'

module Sanford::Config

  class BaseTests < Assert::Context
    desc "Sanford::Config"
    subject{ Sanford::Config }

    should have_instance_methods :services_file, :logger
  end

end
