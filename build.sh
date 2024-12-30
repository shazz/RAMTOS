clear
echo Creating folders if not yet created
mkdir -p build
mkdir -p TOS
mkdir -p tmp
mkdir -p bin
rm -rf bin/*


echo Building RAMTOS8B
tools/vasmm68k_mot -devpac -spaces -nosym -Ftos -D_RAMTOS_=1 -D_SELTOS_=1 src/RAMTOS8.S -o build/RAMTOS8B.PRG -L build/RAMTOS8B.LS
echo Done!

echo Building RAMTOS8
tools/vasmm68k_mot -devpac -spaces -nosym -Ftos -D_RAMTOS_=0 -D_SELTOS_=1 src/RAMTOS8.S -o build/RAMTOS8.PRG -L build/RAMTOS8.LS
echo Done!

echo Building SELTO8
tools/vasmm68k_mot -devpac -spaces -nosym -Ftos -D_RAMTOS_=0 -D_SELTOS_=0 src/RAMTOS8.S -o build/SELTOS8.PRG -L build/SELTOS8.LS
echo Done!
