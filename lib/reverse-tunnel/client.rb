module ReverseTunnel
  class Client
    class Tunnel

      attr_accessor :host, :port
      attr_accessor :token, :local_port

      def initialize(attributes = {})
        attributes.each { |k,v| send "#{k}=", v }
      end

      attr_accessor :connection

      def connection=(connection)
        if connection.nil?
          EventMachine.add_timer(30) do  
            start
          end

          local_connections.close_all
        end

        @connection = connection
      end

      def start
        ReverseTunnel.logger.info "Connect to #{host}:#{port}"
        EventMachine.connect host, port, TunnelConnection, self
      end

      def open
        connection.send_data Message::OpenTunnel.new(token).pack
      end

      def open_session(session_id)
        local_host = "localhost"
        EventMachine.connect local_host, local_port, LocalConnection, self, session_id
      end

      def send_data(session_id, data)
        if connection
          ReverseTunnel.logger.debug "Send data to local connection #{session_id}"
          connection.send_data Message::Data.new(session_id,data).pack
        end
      end

      def local_connections
        @local_connections ||= LocalConnections.new
      end

      def receive_data(session_id, data)
        local_connection = local_connections.find(session_id)
        if local_connection
          ReverseTunnel.logger.debug "Send data to local connection #{session_id}"
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
        ReverseTunnel.logger.debug "Clear buffer for #{session_id}"

        (buffers.delete(session_id) or []).each do |data|
          connection.send_data data
        end
      end
      alias_method :<<, :push

      def buffers
        @buffers ||= Hash.new { |h,k| h[k] = [] }
      end

      def bufferize(session_id, data)
        ReverseTunnel.logger.debug "Push buffer for #{session_id}"
        buffers[session_id] << data
      end

      def delete(connection)
        connections.delete connection
      end

      def close_all
        connections.each(&:close_connection)
      end

    end

    class TunnelConnection < EventMachine::Connection
      attr_accessor :tunnel

      def initialize(tunnel)
        @tunnel = tunnel
      end

      def post_init
        ReverseTunnel.logger.debug "New tunnel connection"
        tunnel.connection = self
        tunnel.open
      end

      def message_unpacker
        @message_unpacker ||= Message::Unpacker.new
      end

      def receive_data(data)
        ReverseTunnel.logger.debug "Received data '#{data.unpack('H*').join}'"
        message_unpacker.feed data

        message_unpacker.each do |message|
          ReverseTunnel.logger.debug "Received message in tunnel #{message.inspect}"

          if message.data?
            tunnel.receive_data message.session_id, message.data
          elsif message.open_session?
            tunnel.open_session message.session_id
          end
        end
      end

      def unbind
        ReverseTunnel.logger.debug "Close tunnel connection"
        tunnel.connection = nil
      end

    end

    class LocalConnection < EventMachine::Connection
      attr_accessor :tunnel, :session_id

      def initialize(tunnel, session_id)
        @tunnel, @session_id = tunnel, session_id
      end

      def post_init
        ReverseTunnel.logger.debug "New local connection"
        tunnel.local_connections << self
      end

      def receive_data(data)
        ReverseTunnel.logger.debug "Received data in local connection #{session_id}"
        tunnel.send_data session_id, data
      end

      def unbind
        ReverseTunnel.logger.debug "Close local connection #{session_id}"
        tunnel.local_connections.delete self
      end

      def send_data(data)
        ReverseTunnel.logger.debug "Send data '#{data.unpack('H*').join}'"
        super
      end

    end

    def start
      EventMachine.run do
        tunnel.start
      end
    end

    def tunnel
      @tunnel ||= Tunnel.new(:token => token, :local_port => local_port, :host => host, :port => port)
    end

    attr_accessor :token, :local_port
    attr_accessor :host, :port

    def initialize(token, local_port = 22)
      @token, @local_port = token, local_port
      @host, @port = "127.0.0.1", 4893
    end

  end
end
