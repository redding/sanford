class TestHost
  include Sanford::Host

  name 'test'

  configure do
    bind 'localhost:8000'
    pid_dir File.join(ROOT, 'tmp')
    logging false
  end

end
