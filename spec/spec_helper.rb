require 'rubygems'

ENV['COVERALLS_DEBUG'] = 'true'
require 'coveralls'

# Fix 'Outside the CI environment, not sending data.'
module Coveralls
  def should_run?
    true
  end

  def will_run?
    true
  end
end if ENV['CI']

Coveralls.wear!

require_relative '../lib/xlint'

RSpec.configure do |c|
  c.raise_errors_for_deprecations!
  c.color = true
end
