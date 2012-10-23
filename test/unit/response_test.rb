require 'assert'

class Sanford::Response

  class BaseTest < Assert::Context
    desc "Sanford::Response"
    setup do
      @response = Sanford::Response.new([ 672, 'YAR!' ], { 'something' => true })
    end
    subject{ @response }

    should have_instance_methods :status, :result
    should have_class_methods :parse

    should "be a subclass of Sanford::Message" do
      assert_kind_of Sanford::Message, subject
    end

    should "have the expected response body" do
      expected_keys = [ 'status', 'result' ].sort
      assert_equal expected_keys, subject.body.keys.sort
      assert_equal 672, subject.body['status'].first
      assert_equal 'YAR!', subject.body['status'].last
      assert_equal({ 'something' => true }, subject.body['result'])
    end
  end

end
