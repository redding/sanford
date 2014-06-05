class BasicServiceHandler
  include Sanford::ServiceHandler

  def run!
    { 'name' => 'Joe Test', 'email' => "joe.test@example.com" }
  end

end

class SerializeErrorServiceHandler
  include Sanford::ServiceHandler

  # return data that fails BSON serialization
  # BSON errors if it is sent date/datetime values
  def run!
    { 'date' => Date.today,
      'datetime' => DateTime.now
    }
  end

end

module CallbackServiceHandler

  def self.included(receiver)
    receiver.class_eval do
      attr_reader :before_init_called, :init_bang_called, :after_init_called
      attr_reader :before_run_called, :run_bang_called, :after_run_called
      attr_reader :second_before_init_called, :second_after_run_called

      before_init do
        @before_init_called = true
      end
      before_init do
        @second_before_init_called = true
      end

      after_init do
        @after_init_called = true
      end

      before_run do
        @before_run_called = true
      end

      after_run do
        @after_run_called = true
      end
      after_run do
        @second_after_run_called = true
      end

    end

  end

  def init!
    @init_bang_called = true
  end

  def run!
    @run_bang_called = true
  end

end

class FlagServiceHandler
  include Sanford::ServiceHandler
  include CallbackServiceHandler

end

class HaltingBehaviorServiceHandler
  include Sanford::ServiceHandler
  include CallbackServiceHandler

  before_init do
    halt_when('before_init')
  end

  def init!
    super
    halt_when('init!')
  end

  after_init do
    halt_when('after_init')
  end

  before_run do
    halt_when('before_run')
  end

  def run!
    super
    halt_when('run!')
  end

  after_run do
    halt_when('after_run')
  end

  def halt_when(method_name)
    return if ![*params['when']].include?(method_name)
    halt(200, {
      :message  => "#{method_name} halting",
      :data     => {
        :before_init_called => @before_init_called,
        :init_bang_called   => @init_bang_called,
        :after_init_called  => @after_init_called,
        :before_run_called  => @before_run_called,
        :run_bang_called    => @run_bang_called,
        :after_run_called   => @after_run_called
      }
    })
  end

end

class RunOtherHandler
  include Sanford::ServiceHandler

  def run!
    response = run_handler(HaltServiceHandler, 'code' => 200, 'data' => 'RunOtherHandler')
    response.data
  end
end

class HaltServiceHandler
  include Sanford::ServiceHandler

  def run!
    halt params['code'], :message => params['message'], :data => params['data']
  end

end

class InvalidServiceHandler; end
