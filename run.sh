echo Building floppy disk
mkdir -p build/ramtos
mkdir -p build/ramtos/AUTO
cp TOS/TOS206FR.IMG build/ramtos/RTOS.IMG
cp build/RAMTOS8B.PRG build/ramtos/AUTO/
tools/dir2msa build/ramtos
tools/msa-to-st-converter build/ build/

rm -rf bin/*
mkdir -p bin
cp -r TOS bin/
cp TOS/TOS206FR.IMG bin/RTOS.IMG
cp TOS/TOS206SW.IMG bin/
cp build/*.PRG bin/
cp -r tests/* bin/
cd /d/projects/stvirus/tools/hatari 
./hatari.exe --machine STE -s 4 --tos "TOS\TOS_v1.62_fr.img" "D:\projects\ACSI2ST\UTILITY\SELTOS\BIN" 

cd /d/projects/ACSI2ST/UTILITY/SELTOS