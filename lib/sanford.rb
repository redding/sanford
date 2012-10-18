require 'sanford/config'
require 'sanford/manager'
require 'sanford/host'
require 'sanford/hosts'
require 'sanford/version'

module Sanford

  class NoServiceHost < RuntimeError
    attr_reader :message

    def initialize(host_name)
      @message = if Sanford::Hosts.empty?
        "No service hosts were defined. " \
        "Please define a service host before trying to run Sanford."
      else
        "A service host couldn't be found with the name #{host_name.inspect}. "
      end
    end
  end

  class NoServicesConfigFile < RuntimeError
    attr_reader :message

    def initialize
      file_path = Sanford::Config.services_config
      @message = "Sanford couldn't require the file '#{file_path}', please make sure it exists or " \
        "modify `Sanford::Config.services_config`."
    end
  end

end
