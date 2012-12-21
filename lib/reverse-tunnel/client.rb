module ReverseTunnel
  class Client
    class Tunnel
      attr_accessor :connection

      def open_session(session_id)
        local_host, local_port = "localhost", 22
        EventMachine.connect local_host, local_port, LocalConnection, self, session_id
      end

      def send_data(session_id, data)
        if connection
          puts "Send data to local connection #{session_id}"
          connection.send_data Message::Data.new(session_id,data).pack
        end
      end

      def local_connections
        @local_connections ||= LocalConnections.new
      end

      def receive_data(session_id, data)
        local_connection = local_connections.find(session_id)
        if local_connection
          puts "Send data to local connection #{session_id}"
          local_connection.send_data data
        else
          local_connections.bufferize session_id, data
        end
      end
    end

    class LocalConnections

      attr_reader :connections

      def initialize
        @connections = []
      end

      def find(session_id)
        connections.find { |c| c.session_id == session_id }
      end

      def push(connection)
        connections << connection

        session_id = connection.session_id
        puts "Clear buffer for #{session_id}"

        (buffers.delete(session_id) or []).each do |data|
          connection.send_data data
        end
      end
      alias_method :<<, :push

      def buffers
        @buffers ||= Hash.new { |h,k| h[k] = [] }
      end

      def bufferize(session_id, data)
        puts "Push buffer for #{session_id}"
        buffers[session_id] << data
      end

      def delete(connection)
        connections.delete connection
      end

    end

    class TunnelConnection < EventMachine::Connection
      attr_accessor :tunnel

      def initialize(tunnel)
        @tunnel = tunnel
      end

      def post_init
        puts "New tunnel connection"
        tunnel.connection = self
      end

      def message_unpacker
        @message_unpacker ||= Message::Unpacker.new
      end

      def receive_data(data)
        puts "Received data '#{data.unpack('H*').join}'"
        message_unpacker.feed data

        message_unpacker.each do |message|
          puts "Received message in tunnel #{message.inspect}"

          if message.data?
            tunnel.receive_data message.session_id, message.data
          elsif message.open?
            tunnel.open_session message.session_id
          end
        end
      end

      def unbind
        puts "Close tunnel connection"
        tunnel.connection = nil
      end

    end

    class LocalConnection < EventMachine::Connection
      attr_accessor :tunnel, :session_id

      def initialize(tunnel, session_id)
        @tunnel, @session_id = tunnel, session_id
      end

      def post_init
        puts "New local connection"
        tunnel.local_connections << self
      end

      def receive_data(data)
        puts "Received data in local connection #{session_id}"
        tunnel.send_data session_id, data
      end

      def unbind
        puts "Close local connection #{session_id}"
        tunnel.local_connections.delete self
      end

      def send_data(data)
        puts "Send data '#{data.unpack('H*')}'"
        super
      end

    end

    def start
      EventMachine.run do
        tunnel = Tunnel.new 

        tunnel_host, tunnel_port = "localhost", 4893
        EventMachine.connect tunnel_host, tunnel_port, TunnelConnection, tunnel
      end
    end
  end
end
