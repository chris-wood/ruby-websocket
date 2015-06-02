require 'socket'
require_relative 'websocket_connection'

class WebSocketServer

	def initialize(options={path: '/', port: 4567, host: 'localhost'})
		@path, @port, @host = options[:path], options[:port], options[:host]
		@tcpServer = TCPServer.new(@host, @port)
	end

	def accept
		socket = @tcpServer.accept()
		puts "Accepted connection"
		send_handshake(socket)
		puts "Sent a handshake"
		WebSocketConnection.new(socket)
	end

	private

	def send_handshake(socket)
		request_line = socket.gets
		header = get_header(socket)
		puts "Parsing header..."
		if (request_line =~ /GET #{@path} HTTP\/1.1/) && (header =~ /Sec-WebSocket-Key: (.*)\r\n/)
			# complete handshake
			ws_accept = create_websocket_accept($1)
			send_handshake_response(socket, ws_accept)
			puts "Completing handshake"
			return true
		end

		# reject the handshake
		puts "Rejecting mofo"
		send_400(socket)
		return false
	end	

	WS_MAGIC_STRING = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

	require 'digest/sha1'
	require 'base64'

	def create_websocket_accept(key)
		digest = Digest::SHA1.digest(key + WS_MAGIC_STRING)
		return Base64.encode64(digest)
	end

	def send_handshake_response(socket, ws_accept)
		socket << "HTTP/1.1 101 Switching Protocols\r\n" +
              "Upgrade: websocket\r\n" +
              "Connection: Upgrade\r\n" +
              "Sec-WebSocket-Accept: #{ws_accept}\r\n"
	end

	def send_400(socket)
		socket << "HTTP/1.1 400 Bad Request\r\n" +
            	  "Content-Type: text/plain\r\n" +
 	              "Connection: close\r\n" +
         	      "\r\n" +
             	  "Incorrect request"
		socket.close
	end	

	def get_header(socket, header = "")
		line = socket.gets()
		if line == "\r\n"
			return header
		else
			return get_header(socket, header + line)
		end
	end

end

