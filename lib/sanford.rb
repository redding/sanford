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

end
