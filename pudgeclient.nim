## The first thing you will always need to do in order to start using pudge db,
## is to create a new instance of the ``Socket`` type using the ``newClient``
## procedure.
##
## Examples
## ========
##
## Connecting to a server
## ----------------------
##
## After you create a socket with the ``newClient`` procedure, you can easily
## connect it to a server running at a known hostname (or IP address) and port.
## To do so, use the example below.
##
## .. code-block:: Nim
##   var client = newClient("127.0.0.1",11213)
##
## Using a server
## ----------------------
##
## Base pudge commands is set and get. Where key is string, value is bytearray
## or string
##
## .. code-block:: Nim
##   var client = newClient("127.0.0.1",11213)
##   discard client.set("key", "val")
##   discard client.set("key", "new_val")
##   echo client.get("key")
##   client.quit()
##
## see test.nim

import net, strutils

const NL = chr(13) & chr(10)

proc newClient*(host: string = "127.0.0.1", port: int = 11213): Socket =
  result = newSocket()
  try:
    result.connect("127.0.0.1", Port(port))
  except:
    raise newException(IOError, "Couldn't connect to server")
  return result


proc set*(socket: Socket, key:string, val:string):bool =
  ##
  ## .. code-block:: Nim
  ##
  ##  let result = client.set("key", "val")
  ##  if result == true:
  ##    echo "STORED"
  ##  else:
  ##    echo "NOT STORED"
  socket.send("set " & key & " 0 0 " & $val.len & NL & val & NL)
  let res = socket.recvLine()
  return res == "STORED"

proc get*(socket: Socket, key:string):string  =
  ##
  ## .. code-block:: Nim
  ##
  ##  let result = client.get("key")
  ##  echo $result
  result = ""
  socket.send("get " & key & NL)
  let res = socket.recvLine()
  #echo res
  while true:
    if res == "END":
      break
    else:
      var size:int
      try:
        let params = splitWhitespace(res & "")
        size = parseInt(params[params.len-1])
      except:
        break
      var data:string =newStringOfCap(size)
      #low level reading from socket(memcopy to cstring)
      let readBytes = socket.recv( cstring(data), size)
      data.setLen(readBytes)
      discard socket.recv(7)#NL+END+NL
      result = $data
      break
  return result

proc quit*(socket: Socket) =
  ## close current session
  socket.send("quit" & NL)