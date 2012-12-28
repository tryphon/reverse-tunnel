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

        ReverseTunnel.logger.debug { "Process http request #{@http_request_uri}" }

        response = EM::DelegatedHttpResponse.new(self)
        response.status = 200
        response.content_type 'application/json'

        begin

          case @http_request_uri 
          when %r{^/tunnels(.json)?$}
            case @http_request_method
            when "GET"
              response.content = server.tunnels.to_json
            when "POST"
              params = @http_post_content ? JSON.parse(@http_post_content) : {}
              tunnel = server.tunnels.create params
              response.content = tunnel.to_json
            end
          when %r{^/tunnels/([0-9A-F]+)(.json)?$}
            tunnel_id = $1
            tunnel = server.tunnels.find(tunnel_id)

            if tunnel
              case @http_request_method
              when "GET"
                response.content = tunnel.to_json
              when "DELETE"
                tunnel = server.tunnels.destroy(tunnel_id)
                response.content = tunnel.to_json
              end
            end
          else 
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

      attr_accessor :token, :local_port, :local_host

      def initialize(attributes)
        attributes.each { |k,v| send "#{k}=", v }
      end

      def local_host
        @local_host ||= "127.0.0.1"
      end

      attr_accessor :connection

      def connection=(connection)
        if @connection and @connection != connection
          @connection.close_connection 
          local_connections.each(&:close_connection)
        end

        @connection = connection

        if @connection
          open
        end
      end

      def connection_closed(connection)
        self.connection = nil if self.connection == connection
      end

      attr_accessor :local_server

      def close
        if local_server
          ReverseTunnel.logger.info "Close local connections on #{local_port}"
          EventMachine.stop_server local_server
          self.local_server = nil
        end

        if connection
          ReverseTunnel.logger.info "Close tunnel connection #{token}"
          self.connection.tap do |connection|
            @connection = nil
            connection.close_connection 
          end
        end
      end

      def open
        unless local_server
          ReverseTunnel.logger.info "Listen on #{local_host}:#{local_port} for #{token}"
          self.local_server = EventMachine.start_server local_host, local_port, LocalConnection, self
        end
      rescue => e
        ReverseTunnel.logger.error "Can't listen on #{local_host}:#{local_port} for #{token} : #{e}"
      end

      def open_session(session_id)
        if connection
          ReverseTunnel.logger.debug { "Send open session #{session_id}" }
          connection.send_data Message::OpenSession.new(session_id).pack
        end
      end

      def ping_received(ping)
        ReverseTunnel.logger.debug { "Receive ping #{token}/#{ping.sequence_number}" }
        connection.send_data Message::Ping.new(ping.sequence_number).pack
      end

      def send_data(session_id, data)
        if connection
          ReverseTunnel.logger.debug { "Send data to local connection #{session_id}" }
          connection.send_data Message::Data.new(session_id,data).pack
        end
      end

      def local_connections
        @local_connections ||= []
      end

      def receive_data(session_id, data)
        local_connection = local_connections.find { |c| c.session_id == session_id }
        if local_connection
          ReverseTunnel.logger.debug { "Send data for local connection #{session_id}" } 
          local_connection.send_data data 
        end
      end

      def next_session_id
        @next_session_id ||= 0
        @next_session_id += 1
      end

      def to_json(*args)
        { :token => token, :local_port => local_port }.tap do |attributes|
          attributes[:connection] = connection.as_json if connection
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

        EventMachine.add_timer(10) do  
          unless open? or closed?
            ReverseTunnel.logger.info "Force close of unopened tunnel connection from #{peer}"
            close_connection 
          end
        end
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
          elsif message.ping?
            tunnel.ping_received message
          end
        end
      end

      attr_accessor :tunnel

      def open?
        !!tunnel
      end

      def closed?
        @closed ||= false
      end

      def close_connection(after_writing = false)
        super
        @closed = true
      end

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
        tunnel.connection_closed self if tunnel
      end

      def peer
        @peer ||= 
          begin
            port, ip = Socket.unpack_sockaddr_in(get_peername)
            "#{ip}:#{port}"
          end
      end

      def as_json(*args)
        { :peer => peer, :created_at => created_at }
      end

    end

    class LocalConnection < EventMachine::Connection
      attr_accessor :tunnel

      def initialize(tunnel)
        @tunnel = tunnel
      end

      def post_init
        ReverseTunnel.logger.debug { "New local connection" }
        tunnel.local_connections << self
        tunnel.open_session(session_id)
      end

      def receive_data(data)
        ReverseTunnel.logger.debug { "Received data in local #{session_id}" }
        tunnel.send_data session_id, data
      end

      def session_id
        @session_id ||= tunnel.next_session_id
      end

      def unbind
        ReverseTunnel.logger.debug { "Close local connection" }
        tunnel.local_connections.delete self
      end

    end

    def tunnels
      @tunnels ||= Tunnels.new
    end

    def local_host=(local_host)
      tunnels.local_host = local_host
    end

    def local_port_range=(local_port_range)
      tunnels.local_port_range = local_port_range
    end

    class Tunnels

      def tunnels
        @tunnels ||= []
      end

      attr_accessor :local_host, :local_port_range

      def local_port_range
        @local_port_range ||= 10000..10200
      end

      def find(token)
        tunnels.find { |t| t.token == token }
      end

      def create(attributes = {})
        attributes = default_attributes.merge(attributes).merge(:local_host => local_host)
        Tunnel.new(attributes).tap do |tunnel|
          ReverseTunnel.logger.info "Create tunnel #{tunnel.inspect}"
          tunnels << tunnel
        end
      end

      def destroy(token)
        tunnel = find(token)
        if tunnel
          tunnel.close
          tunnels.delete tunnel
          tunnel
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
      EventMachine.run do
        start_server
        start_api
      end
    end

    attr_accessor :server_host, :server_port

    def server_host
      @server_host ||= "0.0.0.0"
    end

    def server_port
      @server_port ||= 4893
    end

    def start_server
      ReverseTunnel.logger.info "Wait tunnel connections on #{server_host}:#{server_port}"
      EventMachine.start_server server_host, server_port, TunnelConnection, self
    end

    attr_accessor :api_host, :api_port

    def api_host
      @api_host ||= "127.0.0.1"
    end

    def api_port
      @api_port ||= 4894
    end

    def start_api
      ReverseTunnel.logger.info "Wait api requests #{api_host}:#{api_port}"
      EventMachine.start_server api_host, api_port, ApiServer, self
    end

  end
end
