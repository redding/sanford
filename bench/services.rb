class ApiHost
  include Sanford::Host

  # TODO - replace all this with configuration stuff later
  def self.name
    'api_host'
  end
  def self.pid_dir
    File.expand_path("../../tmp", __FILE__)
  end

end
