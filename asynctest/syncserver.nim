import net, threadpool, strutils

const bytes = 8
const content = repeatStr(bytes, "x")

proc processClient(client: Socket) =
  while true:
    #var line {.inject.}: TaintedString = ""
    #readLine(client, line)
    var line = client.recvLine()
    if line != "":
      echo "line:",line
      client.send(content)
      if line == "quit":
        client.close()
        break
    else:
      client.close()
      break

proc main()=
  let socket = newSocket(domain = AF_INET, sockType = SOCK_STREAM,
    protocol = IPPROTO_TCP, buffered = true)
  setSockOpt(socket, OptReuseAddr, true)
  setSockOpt(socket, OptReusePort, true)
  socket.bindAddr(Port(11213),"127.0.0.1")
  socket.listen()
  while true:
    var client: Socket = newSocket()
    socket.accept(client)
    spawn processClient(client)

main()