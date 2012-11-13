require 'sanford/config'
require 'sanford/manager'
require 'sanford/host'
require 'sanford/version'

module Sanford

  def self.config
    Sanford::Config
  end

  def self.configure(&block)
    self.config.define(&block)
    self.config
  end

  def self.init
    require self.config.services_config
  end

  class NullLogger
    require 'logger'

    Logger::Severity.constants.each do |name|
      define_method(name.downcase){|*args| } # no-op
    end

  end

end
