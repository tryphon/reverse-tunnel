require "reverse-tunnel/version"

require "logger"

module ReverseTunnel

  @@logger = Logger.new($stderr)
  def self.logger
    @@logger
  end
  def self.logger=(logger)
    @@logger = logger
  end

end

require "eventmachine"
require "msgpack"

require "reverse-tunnel/message"
require "reverse-tunnel/server"
require "reverse-tunnel/client"
require "reverse-tunnel/cli"
