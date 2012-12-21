module ReverseTunnel
  class Message

    def self.type
      name.split("::").last.downcase.to_sym
    end
    def type
      self.class.type
    end

    @@types = [:open, :data]
    def self.types
      @@types
    end

    types.each do |type|
      define_method "#{type}?" do
        self.type == type
      end
    end

    def self.type_id
      types.index(type)
    end
    def type_id
      self.class.type_id
    end

    def pack
      [type_id, *payload].to_msgpack
    end

    def self.create(type)
      type = types.at(type) if Fixnum === type
      const_get(type.capitalize).new
    end

    class Unpacker

      attr_reader :unpacker

      def initialize
        @unpacker = MessagePack::Unpacker.new
      end

      def feed(data)
        unpacker.feed data
      end

      include Enumerable
      def each(&block)
        unpacker.each do |data|
          type_id = data.shift
          payload = data

          Message.create(type_id).tap do |message|
            message.load(payload)

            yield message
          end
        end
      end

    end

    def self.unpack(data)
      Unpacker.new.tap do |packer|
        packer.feed data
      end.first
    end

    class Data < Message
      attr_accessor :session_id, :data

      def initialize(session_id = nil, data = nil)
        self.session_id = session_id
        self.data = data
      end

      def payload
        [session_id, data]
      end

      def load(payload)
        self.session_id, self.data = payload
      end
    end

    class Open < Message
      attr_accessor :session_id

      def initialize(session_id = nil)
        self.session_id = session_id
      end

      def payload
        [session_id]
      end

      def load(payload)
        self.session_id = payload.first
      end
      
    end

  end
end

