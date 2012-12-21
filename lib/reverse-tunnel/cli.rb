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
      klass = (mode == "server" ? Server : Client)
      klass.new.start
    end
  end
end
