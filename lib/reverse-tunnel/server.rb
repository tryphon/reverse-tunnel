require 'evma_httpserver'
require 'json'

module ReverseTunnel
  class Server

    class ApiServer < EM::Connection
      include EM::HttpServer

      attr_accessor :server

      def initialize(server)
        @server = server
      end
      
      def post_init
        super
        no_environment_strings
      end

      def process_http_request
        # the http request details are available via the following instance variables:
        #   @http_protocol
        #   @http_request_method
        #   @http_cookie
        #   @http_if_none_match
        #   @http_content_type
        #   @http_path_info
        #   @http_request_uri
        #   @http_query_string
        #   @http_post_content
        #   @http_headers

        ReverseTunnel.logger.debug "Process http request #{@http_request_uri}"

        if @http_request_uri =~ %r{^/tunnels(.json)?$}
          if @http_request_method == "GET"
            response = EM::DelegatedHttpResponse.new(self)
            response.status = 200
            response.content_type 'application/json'
            response.content = server.tunnels.to_json
            response.send_response
          elsif @http_request_method == "POST"
            params = @http_post_content ? JSON.parse(@http_post_content) : {}

            tunnel = server.tunnels.create params

            response = EM::DelegatedHttpResponse.new(self)
            response.status = 200
            response.content_type 'application/json'
            response.content = tunnel.to_json
            response.send_response
          end
        else 
          response = EM::DelegatedHttpResponse.new(self)
          response.status = 404
          response.send_response
        end
      end

    end


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
        ReverseTunnel.logger.info "Close tunnel connection #{token}"
        EventMachine.stop_server local_server
      end

      def open
        ReverseTunnel.logger.info "Listen on #{local_port} for #{token}"
        local_host = "0.0.0.0"
        self.local_server = EventMachine.start_server local_host, local_port, LocalConnection, self
      end

      def open_session(session_id)
        if connection
          ReverseTunnel.logger.debug "Send open session #{session_id}"
          connection.send_data Message::OpenSession.new(session_id).pack
        end
      end

      def send_data(session_id, data)
        if connection
          ReverseTunnel.logger.debug "Send data to local connection #{session_id}"
          connection.send_data Message::Data.new(session_id,data).pack
        end
      end

      def local_connections
        @local_connections ||= []
      end

      def receive_data(session_id, data)
        local_connection = local_connections.find { |c| c.session_id == session_id }
        if local_connection
          ReverseTunnel.logger.debug "Send data for local connection #{session_id}"
          local_connection.send_data data 
        end
      end

      def next_session_id
        @next_session_id ||= 0
        @next_session_id += 1
      end

      def to_json(*args)
        { :token => token, :local_port => local_port }.tap do |attributes|
          attributes[:connection] = connection.to_json if connection
        end.to_json(*args)
      end

    end

    class TunnelConnection < EventMachine::Connection
      attr_accessor :server, :created_at

      def initialize(server)
        @server = server
      end

      def post_init
        ReverseTunnel.logger.info "New tunnel connection from #{peer}"
        self.created_at = Time.now
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
        self.tunnel = server.tunnels.find token
        if tunnel
          ReverseTunnel.logger.info "Open tunnel #{token}"
          tunnel.connection = self
        else
          ReverseTunnel.logger.warn "Refuse tunnel connection #{token}"
          close_connection
        end
      end

      def unbind
        tunnel.connection = nil if tunnel
      end

      def peer
        @peer ||= 
          begin
            port, ip = Socket.unpack_sockaddr_in(get_peername)
            "#{ip}:#{port}"
          end
      end

      def to_json(*args)
        { :peer => peer, :created_at => created_at }
      end

    end

    class LocalConnection < EventMachine::Connection
      attr_accessor :tunnel

      def initialize(tunnel)
        @tunnel = tunnel
      end

      def post_init
        ReverseTunnel.logger.debug "New local connection"
        tunnel.local_connections << self
        tunnel.open_session(session_id)
      end

      def receive_data(data)
        ReverseTunnel.logger.debug "Received data in local #{session_id}"
        tunnel.send_data session_id, data
      end

      def session_id
        @session_id ||= tunnel.next_session_id
      end

      def unbind
        ReverseTunnel.logger.debug "Close local connection"
        tunnel.local_connections.delete self
      end

    end

    def tunnels
      @tunnels ||= Tunnels.new
    end

    class Tunnels

      def tunnels
        @tunnels ||= []
      end

      attr_accessor :local_port_range
      def local_port_range
        @local_port_range ||= 10000..10200
      end

      def find(token)
        tunnels.find { |t| t.token == token }
      end

      def create(attributes = {})
        attributes = default_attributes.merge(attributes)
        Tunnel.new(attributes["token"], attributes["local_port"]).tap do |tunnel|
          ReverseTunnel.logger.info "Create tunnel #{tunnel.inspect}"
          tunnels << tunnel
        end
      end

      def default_attributes
        { "token" => create_token, "local_port" => available_local_port }
      end

      def create_token
        rand(10e32).to_s(16).ljust(28, '0').upcase
      end

      def used_local_ports
        tunnels.map(&:local_port)
      end

      def available_local_ports
        local_port_range.to_a - used_local_ports
      end

      def available_local_port
        available_local_ports.tap do |ports|
          ports.shuffle if respond_to?(:shuffle)
        end.first
      end

      def to_json(*args)
        tunnels.to_json(*args)
      end

    end

    def start
      tunnels.create "token" => "6B833D3F561369156820B4240C7C2657", "local_port" => 10000

      EventMachine.run do
        public_host, public_port = "0.0.0.0", 4893
        EventMachine.start_server public_host, public_port, TunnelConnection, self

        api_host, api_port = "0.0.0.0", 5000
        EventMachine.start_server api_host, api_port, ApiServer, self
      end
    end
  end
end
