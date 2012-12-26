module ReverseTunnel
  class CLI

    attr_accessor :arguments

    def initialize(arguments = [])
      @arguments = arguments
    end

    def mode
      @mode ||= arguments.shift
    end

    class Base

      attr_reader :arguments

      def initialize(arguments = [])
        @arguments = arguments
      end

      def options
        @options ||= Trollop::with_standard_exception_handling(parser) do
          parser.parse arguments
        end
      end

      def configure(object = self)
        options.each do |k,v| 
          unless [:help, :version].include? k or k.to_s =~ /_given$/
            object.send "#{k.to_s.gsub('-','_')}=", v 
          end
        end

        object
      end

    end

    class Global < Base

      def parser
        @parser ||= Trollop::Parser.new do
          banner <<-EOS
Usage:
       reverse-client [global options] server|client [options]

where [global options] are:
EOS

          opt :debug, "Enable debug messages"
          opt :syslog, "Send log messages to syslog"

          version ReverseTunnel::VERSION

          stop_on "server", "client"
        end
      end

    end

    class Configurator < Base

      def instance
        @instance ||= ReverseTunnel.const_get(self.class.name.split("::").last).new
      end

      def method_missing(name, *args)
        instance.send name, *args
      end
      
      def parse_host_port(string)
        host, port = string.split(':')
        [ host, port.to_i ]
      end

      def parse_host_port_range(string)
        if string =~ /(.*):(\d+)-(\d+)$/
          [ $1, ($2.to_i)..($3.to_i) ]
        end
      end

      def server=(server)
        self.server_host, self.server_port = parse_host_port(server)
      end

      def self.configure(arguments)
        new(arguments).configure
      end

    end

    class Client < Configurator

      def parser
        @parser ||= Trollop::Parser.new do
          opt :server, "Host and port of ReverseTunnel server", :type => :string
          opt :"local-port", "Port to forward incoming connection", :default => 22
        end
      end

      def token
        arguments.first
      end

      def configure(object = self)
        super
        self.token = token
        instance
      end

    end

    class Server < Configurator

      def parser
        @parser ||= Trollop::Parser.new do
          opt :server, "Host and port of ReverseTunnel server", :default => "0.0.0.0:4893"
          opt :api, "Host and port of ReverseTunnel HTTP api", :default => "127.0.0.1:4894"
          opt :local, "Host and port range to listen forwarded connections", :default => "127.0.0.1:10000-10010"
        end
      end

      def api=(api)
        self.api_host, self.api_port = parse_host_port(api)
      end

      def local=(local)
        self.local_host, self.local_port_range = parse_host_port_range(local)
      end

    end

    def debug=(debug)
      level = debug ? Logger::DEBUG : Logger::INFO
      ReverseTunnel.logger.level = level
    end

    def syslog=(syslog)
      if syslog
        syslog_logger = Syslog::Logger.new("rtunnel").tap do |logger|
          logger.level = ReverseTunnel.logger.level
        end
        ReverseTunnel.logger = syslog_logger
      end
    end

    def configurator_class
      mode == "server" ? ReverseTunnel::CLI::Server : ReverseTunnel::CLI::Client
    end

    def instance
      configurator_class.configure(arguments)
    end

    def configure
      Global.new(arguments).configure(self)
    end

    def run
      configure
      instance.start
    end
  end
end
