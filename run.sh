rm -rf bin/*
mkdir -p bin
cp -r TOS bin/

echo Copy a few TOS images in the root dir
cp TOS/TOS206FR.IMG bin/RTOS.IMG
cp TOS/TOS206SW.IMG bin/
cp TOS/TOS206X.IMG bin/
cp TOS/TOS104FR.IMG bin/

cp build/*.TOS bin/
cp -r tests/* bin/
cd /d/projects/stvirus/tools/hatari 
# ./hatari.exe --machine STE -s 4 --tos "TOS\TOS_v1.62_fr.img" "D:\projects\ACSI2ST\UTILITY\SELTOS\BIN" 
./hatari.exe --machine ST -s 2 --tos "TOS\TOS_v1.00_us.img" "D:\projects\ACSI2ST\UTILITY\SELTOS\build\ramtos.st" 

cd /d/projects/ACSI2ST/UTILITY/SELTOS