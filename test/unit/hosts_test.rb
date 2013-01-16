require 'assert'

class Sanford::Hosts

  class BaseTest < Assert::Context
    desc "Sanford::hosts"
    setup do
      @hosts = Sanford::Hosts.new
    end
    subject{ @hosts }

    should have_instance_methods :add, :first, :find

  end

  class FindTest < BaseTest
    desc "find"
    setup do
      @hosts.add ::NotNamedHost
      @hosts.add ::NamedHost
      @hosts.add ::BadlyNamedHost
    end

    should "allow finding hosts by their class name or configured name" do
      assert_includes NotNamedHost, subject
      assert_includes NamedHost,    subject
      assert_equal NotNamedHost,  subject.find('NotNamedHost')
      assert_equal NamedHost,     subject.find('NamedHost')
      assert_equal NamedHost,     subject.find('named_host')
    end

    should "check class name before configured name" do
      assert_includes BadlyNamedHost, subject
      assert_equal NotNamedHost, subject.find('NotNamedHost')
    end

    # Using this syntax because these classes need to be defined as top-level
    # constants for ease in using their class names in the tests

    ::NotNamedHost = Class.new do
      include Sanford::Host
    end

    ::NamedHost = Class.new do
      include Sanford::Host
      name 'named_host'
    end

    ::BadlyNamedHost = Class.new do
      include Sanford::Host
      name 'NotNamedHost'
    end

  end

end
