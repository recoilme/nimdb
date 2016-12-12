import asyncnet, asyncdispatch,strutils

var clients {.threadvar.}: seq[AsyncSocket]
const bytes = 800
const content = repeatStr(bytes, "x")

proc processClient(client: AsyncSocket) {.async.} =
  while true:
    let line = await client.recvLine()
    if line=="" or line=="quit":
      echo "terminate"
      client.close()
      for i,cl in clients:
        if cl == client:
          clients.delete(i)
          break
      break
    await client.send(content)

proc serve() {.async.} =
  clients = @[]
  var server = newAsyncSocket()
  server.bindAddr(Port(12345))
  server.listen()
  
  while true:
    echo "new client"
    let client = await server.accept()
    clients.add client
    
    asyncCheck processClient(client)

asyncCheck serve()
runForever()