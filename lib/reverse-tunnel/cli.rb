module ReverseTunnel
  class CLI

    attr_accessor :arguments

    def initialize(arguments)
      @arguments = arguments
    end

    def mode
      @mode ||= arguments.shift
    end

    def run
      if mode == "server"
        Server.new.start
      else
        Client.new(*arguments).start
      end
    end
  end
end
