module ReverseTunnel
  class Server
    class Tunnel
      attr_accessor :connection

      def open_session(session_id)
        if connection
          puts "Send open session #{session_id}"
          connection.send_data Message::Open.new(session_id).pack
        end
      end

      def send_data(session_id, data)
        if connection
          puts "Send data to local connection #{session_id}"
          connection.send_data Message::Data.new(session_id,data).pack
        end
      end

      def local_connections
        @local_connections ||= []
      end

      def receive_data(session_id, data)
        local_connection = local_connections.find { |c| c.session_id == session_id }
        if local_connection
          puts "Send data for local connection #{session_id}"
          local_connection.send_data data 
        end
      end

      def next_session_id
        @next_session_id ||= 0
        @next_session_id += 1
      end

    end

    class TunnelConnection < EventMachine::Connection
      attr_accessor :server

      def initialize(server)
        @server = server
      end

      def post_init
        puts "New tunnel connection"
        tunnel.connection = self
      end

      def message_unpacker
        @message_unpacker ||= Message::Unpacker.new
      end

      def receive_data(data)
        message_unpacker.feed data

        message_unpacker.each do |message|
          tunnel.receive_data message.session_id, message.data
        end
      end

      def tunnel
        server.tunnels.first
      end

      def unbind
        puts "Close tunnel connection"
        tunnel.connection = nil
      end
    end

    class LocalConnection < EventMachine::Connection
      attr_accessor :tunnel

      def initialize(tunnel)
        @tunnel = tunnel
      end

      def post_init
        puts "New local connection"
        tunnel.local_connections << self
        tunnel.open_session(session_id)
      end

      def receive_data(data)
        puts "Received data in local #{session_id}"
        tunnel.send_data session_id, data
      end

      def session_id
        @session_id ||= tunnel.next_session_id
      end

      def unbind
        puts "Close local connection"
        tunnel.local_connections.delete self
      end

    end

    attr_accessor :tunnels

    def initialize
      @tunnels = []
    end

    def start
      tunnel = Tunnel.new
      tunnels << tunnel

      EventMachine.run do
        public_host, public_port = "0.0.0.0", 4893
        EventMachine.start_server public_host, public_port, TunnelConnection, self

        local_host, local_port = "0.0.0.0", 10000
        EventMachine.start_server local_host, local_port, LocalConnection, tunnel
      end
    end
  end
end
