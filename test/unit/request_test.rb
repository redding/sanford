require 'assert'

class Sanford::Request

  class BaseTest < Assert::Context
    desc "Sanford::Request"
    setup do
      @request = Sanford::Request.new('some/service', [ true ])
    end
    subject{ @request }

    should have_instance_methods :service_name, :params
    should have_class_methods :parse

    should "be a subclass of Sanford::Message" do
      assert_kind_of Sanford::Message, subject
    end

    should "have the expected request body" do
      expected_keys = [ 'name', 'params' ].sort
      assert_equal expected_keys, subject.body.keys.sort
      assert_equal 'some/service', subject.body['name']
      assert_equal [ true ], subject.body['params']
    end
  end

end
