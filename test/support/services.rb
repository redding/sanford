class TestHost
  include Sanford

  # TODO - replace all this with configuration stuff later
  def self.pid_dir
    File.join(ROOT, 'tmp')
  end

end
