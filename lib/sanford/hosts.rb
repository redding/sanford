require 'set'
require 'sanford/host'

module Sanford

  class Hosts

    def initialize(values = [])
      @set = Set.new(values)
    end

    def method_missing(method, *args, &block)
      @set.send(method, *args, &block)
    end

    def respond_to?(method)
      super || @set.respond_to?(method)
    end

    # We want class names to take precedence over a configured name, so that if
    # a user specifies a specific class, they always get it
    def find(name)
      find_by_class_name(name) || find_by_name(name)
    end

    private

    def find_by_class_name(class_name)
      @set.detect{|host_class| host_class.to_s == class_name.to_s }
    end

    def find_by_name(name)
      @set.detect{|host_class| host_class.name == name.to_s }
    end

  end

end
