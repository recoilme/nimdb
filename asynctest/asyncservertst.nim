import net, threadpool, times
{.experimental.}

const NL = chr(13) & chr(10)

proc newTask(task:int) = 
  var socket = newSocket()
  socket.connect("127.0.0.1",Port(12345))
  echo "task",$task
  for i in 1..100_000:
    let resp = $task & ":" & $i & NL
    socket.send(resp)
    let res = socket.recv(2000)
    
    #echo $resp,$res
  socket.send("quit")
  socket.close()

proc main()=
  echo "start"
  var t = toSeconds(getTime())
  parallel:
    for i in 1..30:
      spawn newTask(i)
  echo "end"
  echo "Read time [s] ", $(toSeconds(getTime()) - t)    

main()