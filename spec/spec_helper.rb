require 'coveralls'
Coveralls.wear!

require_relative '../lib/xlint'

RSpec.configure do |c|
  c.raise_errors_for_deprecations!
  c.color = true
end
