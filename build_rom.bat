@echo off

echo Building SM Practice Hack

echo Building and pre-patching
cp build\hack.sfc build\HACK_Savestates.sfc && asar\asar.exe --no-title-check save.asm build\HACK_Savestates.sfc && cd ..

PAUSE
