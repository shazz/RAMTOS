echo Rebuild in case of
./build.sh

echo Building floppy disk
mkdir -p build/ramtos
mkdir -p build/ramtos/AUTO
cp TOS/TOS206FR.IMG build/ramtos/RTOS.IMG
cp build/RAMTOS8B.TOS build/ramtos/AUTO/RAMTOS8B.PRG
tools/dir2msa build/ramtos
tools/msa-to-st-converter build/ build/
