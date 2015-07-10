require 'restclient'
require 'websocket'
require 'socket'
require 'openssl'
require 'nokogiri'
require 'json'

# rubocop:disable ClassLength
module ACIrb
  # Event channel interface

  class EventChannel
    attr_accessor :rest

    class ApicWebSocketRecvTimeout < StandardError
    end

    class WebSocketNoHandshake < StandardError
    end

    def initialize(rest, _options = {})
      @rest = rest

      uri = URI.parse(@rest.baseurl)

      if uri.scheme == 'https'
        scheme = 'wss'
        secure = true
      else
        scheme = 'ws'
        secure = false
      end

      url = '%s://%s/socket%s' % [scheme, uri.host, rest.auth_cookie]

      @handshake = WebSocket::Handshake::Client.new(url: url)
      @frame = WebSocket::Frame::Incoming::Server.new(version: @handshake.version)

      @socket = TCPSocket.new(@handshake.host, uri.port)

      if secure
        puts 'connecting over secure websocket'
        ctx = OpenSSL::SSL::SSLContext.new

        ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE unless rest.verify

        ssl_sock = OpenSSL::SSL::SSLSocket.new(@socket, ctx)
        ssl_sock.sync_close = true
        ssl_sock.connect

        @transport_socket = @socket
        @socket = ssl_sock
      else
        @transport_socket = nil
      end

      @socket.write(@handshake.to_s)
      @socket.flush

      loop do
        data = @socket.getc
        next if data.nil?

        @handshake << data

        if @handshake.finished?
          fail @handshake.error.to_s unless @handshake.valid?
          @handshaked = true
          break
        end
      end
    end

    def send(data, type = :text)
      fail WebSocketNoHandshake unless @handshaked

      data = WebSocket::Frame::Outgoing::Client.new(
        version: @handshake.version,
        data: data,
        type: type
      ).to_s
      @socket.write data
      @socket.flush
    end

    def receive(timeout = nil)
      fail WebSocketNoHandshake unless @handshaked

      readable, writable, error = IO.select([@socket], nil, nil, timeout)
      if readable
        begin
          data = @socket.read_nonblock(1024)
        rescue Errno::EAGAIN, Errno::EWOULDBLOCK, (IO::WaitReadable if defined?(IO::WaitReadable)) => e
          puts '%s, retrying' % e
          retry
        end
      else
        fail ApicWebSocketRecvTimeout, 'Timeout for websocket read'
      end
      @frame << data

      messages = []
      while message = @frame.next
        if message.type === :ping
          send(message.data, :pong)
          return messages
        end
        messages << message.to_s
      end

      events = []
      messages.each do |msg|
        events += MoEvent.parse_event(self, msg.to_s)
      end
      events
    end

    def close
      @socket.close
    end
  end

  class MoEvent
    def initialize(_options = {})
    end

    def self.parse_event(event_channel, event_str)
      subscription = nil
      events = []

      if event_channel.rest.format == 'xml'
        doc = Nokogiri::XML(event_str)
        subscription_id = doc.at_css('imdata')['subscriptionId']
        puts event_str
        doc.root.elements.each do |xml_obj|
          event = {
            type: xml_obj.attributes['status'].to_s,
            properties: Hash[xml_obj.attributes.map { |k, str| [k, str.value.to_s] }],
            class: xml_obj.name,
            subscription_id: subscription_id
          }
          events.push(event)
        end
      elsif event_channel.rest.format == 'json'
        doc = JSON.parse(event_str, symbolize_names: false)
        subscription_id = doc['subscriptionId']
        imdata = doc['imdata']
        imdata.each do |obj|
          cls = obj.keys[0]
          event = {
            type: obj[cls]['attributes']['status'].to_s,
            properties: Hash[obj[cls]['attributes'].map { |k, str| [k, str.to_s] }],
            class: cls,
            subscription_id: subscription_id[0]
          }
          events.push(event)
        end

      end

      events
    end
  end
end
