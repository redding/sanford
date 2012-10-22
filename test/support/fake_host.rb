class FakeHost
  include Sanford::Host

  configure do
    host    'fake.local'
    port    8000
    pid_dir '/path/to/pids'
  end
end



