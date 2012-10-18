class BenchHost
  include Sanford::Host

  configure do
    port    12000
    pid_dir File.expand_path("../../tmp", __FILE__)
  end

end
