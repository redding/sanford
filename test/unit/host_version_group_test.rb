require 'assert'

class Sanford::HostVersionGroup

  class BaseTest < Assert::Context
    desc "Sanford::Host::VersionGroup"
    setup do
      @version_group = Sanford::HostVersionGroup.new('v1'){ }
    end
    subject{ @version_group }

    should have_instance_methods :name, :services, :service, :to_hash

    should "add a key-value to it's services hash with #service" do
      subject.service('test', 'MyServiceHandler')

      assert_equal 'MyServiceHandler', subject.services['test']
    end
    should "allow setting a namespace and use it when a service is added" do
      subject.service_handler_ns 'MyNamespace'
      subject.service('test', 'MyServiceHandler')

      assert_equal 'MyNamespace::MyServiceHandler', subject.services['test']
    end
    should "ignore a namespace and when a service class has leading colons" do
      subject.service_handler_ns 'MyNamespace'
      subject.service('test', '::MyServiceHandler')

      assert_equal '::MyServiceHandler', subject.services['test']
    end
    should "return a hash with it's name as a key and its services as the value with #to_hash" do
      subject.service('test', 'MyServiceHandler')
      expected = { subject.name => subject.services }

      assert_equal expected, subject.to_hash
    end
  end

end
