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

  attr_reader :init_bang_called, :before_run_called, :run_bang_called, :after_run_called

  def init!
    @init_bang_called = true
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

  def init!
    super
    halt 200, :message => 'init! halting' if [*params['when']].include?('init!')
  end

  def before_run
    super
    halt 200, :message => 'before_run halting' if [*params['when']].include?('before_run')
  end

  def run!
    super
    halt 200, :message => 'run! halting' if [*params['when']].include?('run!')
  end

  def after_run
    super
    halt 200, :message => 'after_run halting' if [*params['when']].include?('after_run')
  end

end
