require 'ostruct'

module FakeHost

  def self.new(options = {})
    options[:name] ||= 'fake_host'

    config = OpenStruct.new({ :pid_dir => 'pid_dir' })
    OpenStruct.new({ :name => options[:name], :config => config })
  end

end



