Bundler.setup(:benchmark)
require 'benchmark'
require 'whysoslow'

require 'bench/client'

module Bench

  class Runner
    # this should match up with bench/services host and port
    HOST_AND_PORT = [ '127.0.0.1', 12000 ]

    REQUESTS = [
      [ 'v1/simple', {}, 10000 ],
      # [ 'v1/memory_check', {}, 10000 ] # TODO - check the server's memory with whysoslow
                                         # probably need a special method to collect the info
                                         # from the server, need to be able to configure
                                         # services before I can do this
    ]

    TIME_MODIFIER = 10 ** 4 # 4 decimal places

    def build_report
      @file = File.open(File.expand_path("../report.txt", __FILE__), "w")
      output "Running benchmark report..."

      REQUESTS.each do |path, params, times|
        self.benchmark_service(path, params, times)
      end

      output "Done running benchmark report"
      @file.close
    end

    def benchmark_service(path, params, times)
      benchmarks = []

      output "\nHitting #{path.inspect} service with #{params.inspect}, #{times} times"
      [*(1..times)].each do |index|
        benchmark = self.hit_service(path, params.merge({ :request_number => index }))
        benchmarks << self.round_time(benchmark.real * 1000.to_f)
        if ((index - 1) % 100 == 0)
          output('.', false)
        end
      end
      output("\n", false)

      total_time = benchmarks.inject(0){|s, n| s + n }
      data = {
        :number_of_requests => times,
        :total_time_taken   => self.round_and_display(total_time),
        :average_time_taken => self.round_and_display(total_time / benchmarks.size),
        :min_time_taken     => self.round_and_display(benchmarks.min),
        :max_time_taken     => self.round_and_display(benchmarks.max)
      }
      size = data.values.map(&:size).max
      output "Total Time:   #{data[:total_time_taken].rjust(size)}ms"
      output "Average Time: #{data[:average_time_taken].rjust(size)}ms"
      output "Min Time:     #{data[:min_time_taken].rjust(size)}ms"
      output "Max Time:     #{data[:max_time_taken].rjust(size)}ms"
      output "\n"
    end

    protected

    def hit_service(path, params)
      Benchmark.measure do
        begin
          client = Bench::Client.new(*HOST_AND_PORT)
          response = client.call(path, params)
        rescue Exception => exception
          puts "FAILED -> #{exception.class}: #{exception.message}"
          puts exception.backtrace.join("\n")
        end
      end
    end

    def output(message, puts = true)
      method = puts ? :puts : :print
      self.send(method, message)
      @file.send(method, message)
      STDOUT.flush if method == :print
    end

    def round_and_display(time_in_ms)
      self.display_time(self.round_time(time_in_ms))
    end

    def round_time(time_in_ms)
      (time_in_ms * TIME_MODIFIER).to_i / TIME_MODIFIER.to_f
    end

    def display_time(time)
      integer, fractional = time.to_s.split('.')
      [ integer, fractional.ljust(4, '0') ].join('.')
    end

  end

end
