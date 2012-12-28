require "reverse-tunnel/version"

require "logger"

module ReverseTunnel

  def self.default_logger
    Logger.new($stderr).tap do |logger|
      logger.level = Logger::INFO
    end
  end

  @@logger = default_logger
  def self.logger
    @@logger
  end
  def self.logger=(logger)
    @@logger = logger
  end

  def self.reset_logger!
    @@logger = default_logger
  end

end

require "eventmachine"
require "msgpack"
require "trollop"

begin
  require "syslog/logger"
rescue LoadError
  require 'syslog_logger'
  Syslog::Logger = SyslogLogger
end

require "reverse-tunnel/message"
require "reverse-tunnel/server"
require "reverse-tunnel/client"
require "reverse-tunnel/cli"
