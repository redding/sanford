class TestServiceHandler
  include Sanford::ServiceHandler

end

class BasicServiceHandler
  include Sanford::ServiceHandler

  def run!
    { 'name' => 'Joe Test', 'email' => "joe.test@example.com" }
  end

end

class FlagServiceHandler
  include Sanford::ServiceHandler

  attr_reader :before_init_called, :init_bang_called, :after_init_called,
    :before_run_called, :run_bang_called, :after_run_called

  def before_init
    @before_init_called = true
  end

  def init!
    @init_bang_called = true
  end

  def after_init
    @after_init_called = true
  end

  def before_run
    @before_run_called = true
  end

  def run!
    @run_bang_called = true
  end

  def after_run
    @after_run_called = true
  end

end

class HaltServiceHandler
  include Sanford::ServiceHandler

  def run!
    halt params['code'], :message => params['message'], :data => params['data']
  end

end

class HaltingBehaviorServiceHandler < FlagServiceHandler

  def before_init
    super
    halt_when('before_init')
  end

  def init!
    super
    halt_when('init!')
  end

  def after_init
    super
    halt_when('after_init')
  end

  def before_run
    super
    halt_when('before_run')
  end

  def run!
    super
    halt_when('run!')
  end

  def after_run
    super
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
