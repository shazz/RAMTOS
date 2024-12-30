clear
echo Creating folders if not yet created
mkdir -p build
mkdir -p TOS
mkdir -p tmp

echo Building RAMTOS8
tools/vasmm68k_mot -devpac -spaces -nosym -Ftos -D_NO_SELECT_=0 src/RAMTOS8.S -o bin/RAMTOS8.PRG -L build/RAMTOS8.LS
echo Done!

echo Building RAMTOS8B
tools/vasmm68k_mot -devpac -spaces -nosym -Ftos -D_NO_SELECT_=1 src/RAMTOS8.S -o bin/RAMTOS8B.PRG -L build/RAMTOS8B.LS
echo Done!