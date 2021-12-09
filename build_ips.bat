@echo off

echo Building SM Savestate Patch
python create_dummies.py 00.sfc ff.sfc

copy *.sfc build
asar\asar.exe --no-title-check save.asm build\00.sfc
asar\asar.exe --no-title-check save.asm build\ff.sfc
python create_ips.py build\00.sfc build\ff.sfc build\HACK_Savestates.ips

del 00.sfc ff.sfc build\00.sfc build\ff.sfc

PAUSE
