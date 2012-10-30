module TestHelper
  module_function

  def preserve_and_clear_hosts
    @previous_hosts = Sanford.config.hosts.dup
    Sanford.config.hosts.clear
  end

  def restore_hosts
    Sanford.config.hosts = @previous_hosts
    @previous_hosts = nil
  end

end
