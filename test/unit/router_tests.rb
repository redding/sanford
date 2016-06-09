require 'assert'
require 'sanford/router'

require 'test/support/factory'

class Sanford::Router

  class UnitTests < Assert::Context
    desc "Sanford::Router"
    setup do
      @router_class = Sanford::Router
    end
    subject{ @router_class }

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @router = @router_class.new
    end
    subject{ @router }

    should have_readers :routes
    should have_imeths :service_handler_ns, :service, :validate!

    should "build an empty array for its routes by default" do
      assert_equal [], subject.routes
    end

    should "not have a service handler ns by default" do
      assert_nil subject.service_handler_ns
    end

    should "allow setting its service handler ns" do
      namespace = Factory.string
      subject.service_handler_ns namespace
      assert_equal namespace, subject.service_handler_ns
    end

    should "allow adding routes using `service`" do
      service_name = Factory.string
      handler_name = Factory.string
      subject.service service_name, handler_name

      route = subject.routes.last
      assert_instance_of Sanford::Route, route
      assert_equal service_name, route.name
      assert_equal handler_name, route.handler_class_name
    end

    should "use its service handler ns when adding routes" do
      namespace = Factory.string
      subject.service_handler_ns namespace

      service_name = Factory.string
      handler_name = Factory.string
      subject.service service_name, handler_name

      route = subject.routes.last
      exp = "#{namespace}::#{handler_name}"
      assert_equal exp, route.handler_class_name
    end

    should "validate each route when validating" do
      subject.service(Factory.string, TestHandler.to_s)
      subject.routes.each{ |route| assert_nil route.handler_class }
      subject.validate!
      subject.routes.each{ |route| assert_not_nil route.handler_class }
    end

    should "know its custom inspect" do
      reference = '0x0%x' % (subject.object_id << 1)
      exp = "#<#{subject.class}:#{reference} " \
            "@service_handler_ns=#{subject.service_handler_ns.inspect}>"
      assert_equal exp, subject.inspect
    end

  end

  TestHandler = Class.new

end
