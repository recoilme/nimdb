import net, threadpool
{.experimental.}

const NL = chr(13) & chr(10)

proc newTask(task:int) = 
  var socket = newSocket()
  socket.connect("127.0.0.1",Port(11213))
  for i in 1..3:
    let resp = $task & ":" & $i & NL
    socket.send(resp)
    let res = socket.recv(8)
    echo $resp,$res
  socket.send("quit")
  socket.close()

proc main()=
  echo "start"
  parallel:
    for i in 1..5:
      spawn newTask(i)
  echo "end"

main()