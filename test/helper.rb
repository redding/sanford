# this file is automatically required when you run `assert`
# put any test helpers here

# add the root dir to the load path
$LOAD_PATH.unshift(File.expand_path("../..", __FILE__))

require 'pry' # require pry for debugging (`binding.pry`)

ENV['SANFORD_PROTOCOL_DEBUG'] = 'yes'

require 'pathname'
ROOT_PATH = Pathname.new(File.expand_path('../..', __FILE__))

require 'test/support/factory'

JOIN_SECONDS = 0.1

# 1.8.7 backfills

# Array#sample
if !(a = Array.new).respond_to?(:sample) && a.respond_to?(:choice)
  class Array
    alias_method :sample, :choice
  end
end
