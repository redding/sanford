require 'assert'

require 'sanford-protocol/test/helpers'

class Sanford::Worker

  # turn off the protocol's debugging (in case it's on) and turn on Sanford's
  # debugging
  class SetupContextToRaiseExceptions < Assert::Context
    setup do
      @env_sanford_protocol_debug = ENV['SANFORD_PROTOCOL_DEBUG']
      @env_sanford_debug = ENV['SANFORD_DEBUG']
      ENV.delete('SANFORD_PROTOCOL_DEBUG')
      ENV['SANFORD_DEBUG'] = '1'
    end
    teardown do
      ENV['SANFORD_DEBUG'] = @env_sanford_debug
      ENV['SANFORD_PROTOCOL_DEBUG'] = @env_sanford_protocol_debug
    end
  end

  class BaseTest < SetupContextToRaiseExceptions
    include Sanford::Protocol::Test::Helpers

    desc "Sanford::Worker"
    setup do
      @worker = Sanford::Worker.new(TestHost.new)
    end
    subject{ @worker }

    should have_instance_methods :logger, :run

  end

  class EchoTest < BaseTest
    desc "running a request for the echo server"
    setup do
      @connection = FakeConnection.with_request('v1', 'echo', { :message => 'test' })
    end

    should "return a successful response and echo the params sent to it" do
      assert_nothing_raised{ @worker.run(@connection) }
      response = @connection.response

      assert_equal 200,     response.status.code
      assert_equal nil,     response.status.message
      assert_equal 'test',  response.data
    end

  end

  class MissingServiceVersionTest < BaseTest
    desc "running a request with no service version"
    setup do
      request_hash = Sanford::Protocol::Request.new('v1', 'what', {}).to_hash
      request_hash.delete('version')
      @connection = FakeConnection.new(request_hash)
    end

    should "return a bad request response" do
      assert_raises(Sanford::Protocol::BadRequestError) do
        @worker.run(@connection)
      end
      response = @connection.response

      assert_equal 400,       response.status.code
      assert_match "request", response.status.message
      assert_match "version", response.status.message
      assert_equal nil,       response.data
    end

  end

  class MissingServiceNameTest < BaseTest
    desc "running a request with no service name"
    setup do
      request_hash = Sanford::Protocol::Request.new('v1', 'what', {}).to_hash
      request_hash.delete('name')
      @connection = FakeConnection.new(request_hash)
    end

    should "return a bad request response" do
      assert_raises(Sanford::Protocol::BadRequestError) do
        @worker.run(@connection)
      end
      response = @connection.response

      assert_equal 400,       response.status.code
      assert_match "request", response.status.message
      assert_match "name",    response.status.message
      assert_equal nil,       response.data
    end

  end

  class NotFoundServiceTest < BaseTest
    desc "running a request with no matching service name"
    setup do
      @connection = FakeConnection.with_request('v1', 'what', {})
    end

    should "return a bad request response" do
      assert_raises(Sanford::NotFoundError) do
        @worker.run(@connection)
      end
      response = @connection.response

      assert_equal 404, response.status.code
      assert_equal nil, response.status.message
      assert_equal nil, response.data
    end

  end

  class ErrorServiceTest < BaseTest
    desc "running a request that errors on the server"
    setup do
      @connection = FakeConnection.with_request('v1', 'bad', {})
    end

    should "return a bad request response" do
      assert_raises(RuntimeError) do
        @worker.run(@connection)
      end
      response = @connection.response

      assert_equal 500,     response.status.code
      assert_match "error", response.status.message
      assert_equal nil,     response.data
    end

  end

  class HaltTest < BaseTest
    desc "running a request that halts"
    setup do
      @connection = FakeConnection.with_request('v1', 'halt_it', {})
    end

    should "return the response that was halted" do
      assert_nothing_raised{ @worker.run(@connection) }
      response = @connection.response

      assert_equal 728,                 response.status.code
      assert_equal "I do what I want",  response.status.message
      assert_equal [ 1, true, 'yes' ],  response.data
    end

  end

  class AuthorizeRequestTest < BaseTest
    desc "running a request that halts in a callback"
    setup do
      @connection = FakeConnection.with_request('v1', 'authorized', {})
    end

    should "return the response that was halted" do
      assert_nothing_raised{ @worker.run(@connection) }
      response = @connection.response

      assert_equal 401,               response.status.code
      assert_equal "Not authorized",  response.status.message
      assert_equal nil,               response.data
    end

  end

end
