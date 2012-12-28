module ReverseTunnel
  class Client

    class ApiServer < EM::Connection
      include EM::HttpServer

      attr_accessor :tunnel

      def initialize(tunnel)
        @tunnel = tunnel
      end
      
      def post_init
        super
        no_environment_strings
      end

      def process_http_request
        ReverseTunnel.logger.debug { "Process http request #{@http_request_uri}" }

        response = EM::DelegatedHttpResponse.new(self)
        response.status = 200
        response.content_type 'application/json'

        begin
          if @http_request_uri =~ %r{^/status(.json)?$} and @http_request_method == "GET"
            response.content = tunnel.to_json
          end
        rescue => e
          ReverseTunnel.logger.error "Error in http request processing: #{e}"
          response.status = 500
        end

        if response.content.nil?
          response.status = 404
        end

        response.send_response
      end
      
    end

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
          @hearbeat.cancel
        else
          @hearbeat = EventMachine.add_periodic_timer(5) do
            ping
          end
        end

        @connection = connection
      end

      def start
        ReverseTunnel.logger.debug { "Connect to #{host}:#{port}" }
        EventMachine.connect host, port, TunnelConnection, self
      end

      def open
        connection.send_data Message::OpenTunnel.new(token).pack
      end

      attr_accessor :sequence_number
      def sequence_number
        @sequence_number ||= 0
      end

      def ping
        next_number = self.sequence_number += 1
        ReverseTunnel.logger.debug { "Send ping #{next_number}" } 
        connection.send_data Message::Ping.new(next_number).pack if connection
      end

      def ping_received(ping)
        ReverseTunnel.logger.info "Receive ping #{ping.sequence_number}"
      end

      def open_session(session_id)
        local_host = "localhost"
        EventMachine.connect local_host, local_port, LocalConnection, self, session_id
      end

      def send_data(session_id, data)
        if connection
          ReverseTunnel.logger.debug { "Send data to local connection #{session_id}" }
          connection.send_data Message::Data.new(session_id,data).pack
        end
      end

      def local_connections
        @local_connections ||= LocalConnections.new
      end

      def receive_data(session_id, data)
        local_connection = local_connections.find(session_id)
        if local_connection
          ReverseTunnel.logger.debug { "Send data to local connection #{session_id}" }
          local_connection.send_data data
        else
          local_connections.bufferize session_id, data
        end
      end

      def to_json
        { :token => token, 
          :local_port => local_port, 
          :server_host => host, 
          :server_port => port,
          :local_connections => local_connections.as_json
        }.tap do |attributes|
          attributes[:connection] = connection.as_json if connection
        end.to_json
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
        ReverseTunnel.logger.debug { "Clear buffer for #{session_id}" }

        (buffers.delete(session_id) or []).each do |data|
          connection.send_data data
        end
      end
      alias_method :<<, :push

      def buffers
        @buffers ||= Hash.new { |h,k| h[k] = [] }
      end

      def bufferize(session_id, data)
        ReverseTunnel.logger.debug { "Push buffer for #{session_id}" }
        buffers[session_id] << data
      end

      def delete(connection)
        connections.delete connection
      end

      def close_all
        connections.each(&:close_connection)
      end

      def as_json
        connections.map(&:as_json)
      end

    end

    class TunnelConnection < EventMachine::Connection
      attr_accessor :tunnel, :created_at

      attr_reader :hearbeat

      def initialize(tunnel)
        @tunnel = tunnel
      end

      def post_init
        ReverseTunnel.logger.debug { "New tunnel connection" }
        self.created_at = Time.now

        tunnel.connection = self
        tunnel.open
      end

      def message_unpacker
        @message_unpacker ||= Message::Unpacker.new
      end

      def as_json
        { :created_at => created_at }
      end

      def receive_data(data)
        ReverseTunnel.logger.debug { "Received data '#{data.unpack('H*').join}'" }
        message_unpacker.feed data

        message_unpacker.each do |message|
          ReverseTunnel.logger.debug { "Received message in tunnel #{message.inspect}" }

          if message.data?
            tunnel.receive_data message.session_id, message.data
          elsif message.open_session?
            tunnel.open_session message.session_id
          elsif message.ping?
            tunnel.ping_received message
          end
        end
      end

      def unbind
        ReverseTunnel.logger.debug { "Close tunnel connection" }
        tunnel.connection = nil
      end

    end

    class LocalConnection < EventMachine::Connection
      attr_accessor :tunnel, :session_id

      attr_reader :created_at, :received_size, :send_size

      def initialize(tunnel, session_id)
        @tunnel, @session_id = tunnel, session_id
        @received_size = @send_size = 0
      end

      def post_init
        ReverseTunnel.logger.debug { "New local connection" }
        @created_at = Time.now
        tunnel.local_connections << self
      end

      def receive_data(data)
        ReverseTunnel.logger.debug { "Received data in local connection #{session_id}" }
        @received_size += data.size
        tunnel.send_data session_id, data
      end

      def unbind
        ReverseTunnel.logger.debug { "Close local connection #{session_id}" }
        tunnel.local_connections.delete self
      end

      def send_data(data)
        ReverseTunnel.logger.debug { "Send data '#{data.unpack('H*').join}'" }
        @send_size += data.size
        super
      end

      def as_json
        { :session_id => session_id, :created_at => created_at, :received_size => received_size, :send_size => send_size }
      end

    end

    def start
      EventMachine.run do
        tunnel.start
        start_api
      end
    end

    def start_api
      if api_host
        ReverseTunnel.logger.info "Wait api requests #{api_host}:#{api_port}"
        EventMachine.start_server api_host, api_port, ApiServer, tunnel
      end
    end

    def tunnel
      @tunnel ||= Tunnel.new(:token => token, :local_port => local_port, :host => server_host, :port => server_port)
    end

    attr_accessor :token, :local_port
    attr_accessor :server_host, :server_port
    attr_accessor :api_host, :api_port

    def server_port
      @server_port ||= 4893
    end

    def api_port
      @api_port ||= 4895
    end

    def local_port
      @local_port ||= 22
    end

  end
end
