require 'benchmark'

namespace :bench do

  TIME_MODIFIER = 10 ** 4

  desc "Run a simple request against the Benchmark server"
  task :simple_request, [ :times ] do |t, args|
    service = 'v1/simple'
    run_requests('v1/simple', {}, args[:times])
  end

  def run_requests(service_path, params, num)
    require 'bench/client'
    client = Bench::Client.new('127.0.0.1', 12000)
    number_of_requests = num.to_i.abs > 0 ? num.to_i.abs : 1

    puts "Testing the Benchmark server with #{number_of_requests} request(s)"
    puts "  service: #{service_path.inspect}"
    benchmarks = []
    [*(1..number_of_requests)].each do |index|
      benchmark = Benchmark.measure do
        begin
          request_params = params || {}
          request_params[:request_number] = index
          response = client.call('v1/simple', request_params)
        rescue Exception => exception
          puts "FAILED -> #{exception.class}: #{exception.message}"
        end
      end
      time_taken = ((benchmark.real * 1000.to_f) * TIME_MODIFIER).to_i / TIME_MODIFIER.to_f
      benchmarks << time_taken
    end
    total_time = benchmarks.inject(0){|s, n| s + n }
    average_time = total_time / benchmarks.size
    average_time = (average_time * TIME_MODIFIER).to_i / TIME_MODIFIER.to_f
    total_time = (total_time * TIME_MODIFIER).to_i / TIME_MODIFIER.to_f
    puts "all requests run"
    puts "average time: #{average_time}ms"
    puts "total time: #{total_time}ms"
  end

end
