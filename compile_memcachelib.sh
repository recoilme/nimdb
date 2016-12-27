cd "$( dirname "${BASH_SOURCE[0]}" )"
cd memcachelib
echo "Compile libhl..."
cd deps/ && autoreconf --install
cd build
../configure
make
cp libhl.a ../..
cd ../..

echo "Compile memcachelib..."
gcc -c -fPIC -I./deps/src -L. -lhl lru.c -o lru.o
gcc lru.o libhl.a -shared -o memcachelib.so
mv -f memcachelib.so ./../libs/linux/memcachelib.so
cd ..
