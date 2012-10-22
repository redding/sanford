class TestHost
  include Sanford::Host

  name 'test'

  configure do
    host    'localhost'
    port    8000
    pid_dir File.join(ROOT, 'tmp')
    logging false
  end

end
