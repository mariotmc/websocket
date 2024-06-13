require "socket"
require "digest/sha1"

server = TCPServer.new("localhost", 2345)

loop do
  socket = server.accept
  STDERR.puts "Incoming Request"

  http_request = ""
  while (line = socket.gets) && (line != "\r\n")
    http_request += line
  end

  if matches = http_request.match(/^Sec-WebSocket-Key: (\S+)/)
    websocket_key = matches[1]
    STDERR.puts "Websocket handshake detected with key: #{websocket_key}"
  else
    STDERR.puts "Aborting non-websocket connection"
    socket.close
    next
  end

  response_key = Digest::SHA1.base64digest([websocket_key, "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"].join)
  STDERR.puts "Responding to handshake with key: #{response_key}"

  socket.write <<-eos
HTTP/1.1 101 Switching Protocols\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Accept: #{response_key}\r
\r
  eos

  STDERR.puts "Handshake completed. Starting to parse the websocket frame."

  loop do
    first_byte = socket.getbyte
    next unless first_byte # Handle socket closure

    fin = first_byte & 0b10000000
    opcode = first_byte & 0b00001111

    raise "We don't support continuations" unless fin
    raise "We only support opcode 1" unless opcode == 1

    second_byte = socket.getbyte
    is_masked = second_byte & 0b10000000
    payload_size = second_byte & 0b01111111

    raise "All incoming frames should be masked according to the websocket spec" unless is_masked
    raise "We only support payloads < 126 bytes in length" unless payload_size < 126

    STDERR.puts "Payload size: #{payload_size} bytes"

    mask = 4.times.map { socket.getbyte }
    STDERR.puts "Got mask: #{mask.inspect}"

    data = payload_size.times.map { socket.getbyte }
    STDERR.puts "Got masked data: #{data.inspect}"

    unmasked_data = data.each_with_index.map { |byte, i| byte ^ mask[i % 4] }
    STDERR.puts "Unmasked the data: #{unmasked_data.inspect}"

    message = unmasked_data.pack("C*").force_encoding("utf-8")
    STDERR.puts "Converted to a string: #{message.inspect}"

    # Echo the message back to the client
    response = [0b10000001, message.bytesize, *message.bytes].pack("C*")
    socket.write(response)

    # Break the loop if the message indicates closure or if no message is received
    break if message.downcase == "close" || message.empty?
  end

  socket.close
end
