FileUtils.mkdir_p "log"

def ReverseTunnel.default_logger
  Logger.new("log/test.log")
end

ReverseTunnel.reset_logger!


