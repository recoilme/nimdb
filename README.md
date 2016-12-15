### Pudge Db - it's modern key/value storage with memcached protocol support.

Pudge Db implements a high-level cross-platform sockets interface to sophia db.

Pudge writen in Nim and uses Sophia engine inside.

Pudge is fast, effective and simple.

## Build
[Install Nim](http://nim-lang.org)

Build server from Nimble:
```
nimble install pudge
cd ~/.nimble/pkgs/Pudge-0.1.0/
nim c pudge.nim
```
Build from source:
```
git clone https://github.com/recoilme/pudge.git
nimble install yaml
nim c pudge.nim

Buld sophia 2.1 branch:
git clone -b v2.1 https://github.com/pmwkaa/sophia.git
cd sophia/
make
g++ -dynamiclib -undefined suppress -flat_namespace sophia.o -o libsophia.dylib #macos
#copy to libs folder
```
Start with the custom configuration:
```
./pudge --config=path/to/config.json
```
## Example
From Nim
```
import pudgeclient

var client = newClient("127.0.0.1",11213)
discard client.set("key", "val")
discard client.set("key", "new_val")
echo client.get("key")
client.quit()
#print new_val
```
From other lang:

Try your favorite memcached client

## Doc

Server doc: https://recoilme.github.io/pudge/pudge.html

Client doc: https://recoilme.github.io/pudge/pudgeclient.html