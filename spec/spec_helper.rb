require 'simplecov'

SimpleCov.start do
  add_filter "/spec/"
end

require 'reverse-tunnel'
include ReverseTunnel

Dir[File.expand_path(File.join(File.dirname(__FILE__),'support','**','*.rb'))].each {|f| require f}

RSpec.configure do |config|
  

end
