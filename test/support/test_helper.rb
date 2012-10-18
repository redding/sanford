module TestHelper
  module_function

  def preserve_and_clear_hosts
    @previous_hosts = Sanford::Hosts.set.dup
    Sanford::Hosts.clear
  end

  def restore_hosts
    Sanford::Hosts.instance_variable_set("@set", @previous_hosts)
    @previous_hosts = nil
  end

end
