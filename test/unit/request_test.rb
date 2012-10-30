require 'assert'

class Sanford::Request

  class BaseTest < Assert::Context
    desc "Sanford::Request"
    setup do
      @request = Sanford::Request.new('some_service', 'v1', [ true ])
    end
    subject{ @request }

    should have_instance_methods :service_name, :service_version, :params
    should have_class_methods :parse

    should "be a subclass of Sanford::Message" do
      assert_kind_of Sanford::Message, subject
    end

    should "have the expected request body" do
      expected_keys = [ 'name', 'version', 'params' ].sort
      assert_equal expected_keys, subject.body.keys.sort
      assert_equal 'some_service', subject.body['name']
      assert_equal 'v1', subject.body['version']
      assert_equal [ true ], subject.body['params']
    end
  end

end
