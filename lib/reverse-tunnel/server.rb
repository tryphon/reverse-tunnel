module ReverseTunnel
  class Server
    class Tunnel
      attr_accessor :token, :local_port

      def initialize(token, local_port)
        @token, @local_port = token, local_port
      end

      attr_accessor :connection

      def connection=(connection)
        @connection = connection

        if connection
          open 
        else
          close
        end
      end

      attr_accessor :local_server

      def close
        EventMachine.stop_server local_server
      end

      def open
        puts "Listen on #{local_port} for #{token}"
        local_host = "0.0.0.0"
        self.local_server = EventMachine.start_server local_host, local_port, LocalConnection, self
      end

      def open_session(session_id)
        if connection
          puts "Send open session #{session_id}"
          connection.send_data Message::OpenSession.new(session_id).pack
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
        # TODO add timeout if tunnel isn't opened
      end

      def message_unpacker
        @message_unpacker ||= Message::Unpacker.new
      end

      def receive_data(data)
        message_unpacker.feed data

        message_unpacker.each do |message|
          if message.data?
            tunnel.receive_data message.session_id, message.data
          elsif message.open_tunnel?
            open_tunnel message.token
          end
        end
      end

      attr_accessor :tunnel

      def open_tunnel(token)
        self.tunnel = server.tunnels.find { |t| t.token == token }
        if tunnel
          puts "Open tunnel #{token}"
          tunnel.connection = self
        else
          puts "Refuse tunnel connection #{token}"
          close_connection
        end
      end

      def unbind
        puts "Close tunnel connection"
        tunnel.connection = nil if tunnel
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
      tunnel = Tunnel.new("6B833D3F561369156820B4240C7C2657", 10000)
      tunnels << tunnel

      EventMachine.run do
        public_host, public_port = "0.0.0.0", 4893
        EventMachine.start_server public_host, public_port, TunnelConnection, self
      end
    end
  end
end
