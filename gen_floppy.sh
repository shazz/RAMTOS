echo Rebuild in case of
./build.sh

echo Building floppy disk using TOS 2.06 FR
mkdir -p build/ramtos
mkdir -p build/ramtos/AUTO
# cp TOS/TOS206FR.IMG build/ramtos/RTOS.IMG
cp TOS/TOS100FR.IMG build/ramtos/RTOS.IMG
cp tests/FLOPPY.INF build/ramtos/DESKTOP.INF
cp build/RAMTOS8B.TOS build/ramtos/AUTO/RAMTOS8B.PRG
cp -r tests/SYSINFO build/ramtos/

echo Building MSA image
tools/dir2msa build/ramtos

echo Building ST image
tools/msa-to-st-converter build/ build/
