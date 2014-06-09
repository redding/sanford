require 'assert'
require 'sanford/hosts'

require 'sanford/host'

class Sanford::Hosts

  class UnitTests < Assert::Context
    desc "Sandford::Hosts"
    setup do
      @hosts = Sanford::Hosts.new
    end
    subject{ @hosts }

    should have_instance_methods :add, :first, :find

  end

  class FindTests < UnitTests
    desc "find method"
    setup do
      @hosts.add ::NotNamedHost
      @hosts.add ::NamedHost
      @hosts.add ::BadlyNamedHost
    end

    should "allow finding hosts by their class name or configured name" do
      assert_includes ::NotNamedHost, subject
      assert_includes ::NamedHost, subject

      assert_equal ::NotNamedHost, subject.find('NotNamedHost')
      assert_equal ::NamedHost, subject.find('NamedHost')
      assert_equal ::NamedHost, subject.find('named_host')
    end

    should "prefer hosts with a matching class name over configured name" do
      assert_includes ::BadlyNamedHost, subject
      assert_equal NotNamedHost, subject.find('NotNamedHost')
    end

  end

  # Using this syntax because these classes need to be defined as top-level
  # constants for ease in using their class names in the tests

  ::NotNamedHost   = Class.new{ include Sanford::Host }
  ::NamedHost      = Class.new{ include Sanford::Host; name 'named_host' }
  ::BadlyNamedHost = Class.new{ include Sanford::Host; name 'NotNamedHost' }

end
