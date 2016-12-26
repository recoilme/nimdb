gcc -c -fPIC linklist.c -o linklist.o
gcc -c -fPIC hashtable.c -o hashtable.o
gcc -c -fPIC cacheimpl2.c -o cacheimpl2.o
gcc cacheimpl2.o hashtable.o linklist.o -shared -o libcacheimpl2.so
mv -f libcacheimpl2.so ./../libs/linux/libcacheimpl2.so
