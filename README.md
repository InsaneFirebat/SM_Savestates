# Super Metroid Savestate Patch

This patch adds the savestate feature to Super Metroid and its romhacks. It uses up to 328h bytes of freespace (or 2D9h if `!RERANDOMIZE` is disabled) and can easily be reconfigured for broader hack compatibility. This is only intended for use with the SD2SNES and FXPAK PRO cartridges and will likely cause crashes if used with Mister, Everdrives, and most emulators (including Virtual Console). The Super NT is compatible, although it may require the "jailbreak" firmware update.

This patch was adapted from the Super Metroid Practice Hack. Find the original at https://github.com/tewtal/sm_practice_hack


## Using the pre-made patch

A pre-made IPS patch is included in the \build\ directory. You will need an IPS patcher utility, such as Lunar IPS or Floating IPS, to apply the patch to your SM romhack. Always use an unheadered (UH) version of the romhack when applying the Savestate patch.


## Using the savestate feature:

By default, the inputs to create a savestate are "Select+Y+R". Once a savestate has been created, you can press "Select+Y+L" (by default) to load the savestate. Savestates cannot be created or loaded during door scrolling, music change, or when message boxes are active.


## Configuring the patch

1. Open `save.asm` in your text editor of choice
2. At the top of the file, you can change the `!FREESPACE` pointer to any unused space in the first 32 banks ($80-BF) of your romhack
3. `!RERANDOMIZE` can be set to `0` to disable the re-randomize RNG feature
4. Button inputs to trigger save/load can be edited at `!SAVE_INPUTS` and `!LOAD_INPUTS`
5. `!ram_room_has_set_rng` and `!sram_save_has_set_rng` can be moved if needed, or ignored if `!RERANDOMIZE` is disabled


## Two ways to build from source:

### Build IPS patch:
1. Download and install Python 3 from https://python.org. Windows users will need to set the PATH environmental variable to point to their Python installation folder.
2. Run build_IPS.bat to create an IPS patch file
4. Locate the patch in \build\

### Patch your rom:

1. Place your unheadered romhack in the \build\ directory
2. Rename the romhack to `hack.sfc`
3. Run `build_rom.bat` to create a copy of your romhack with the Savestate patch applied
4. Locate the patched rom in \build\


## Known Issues:

* Making a savestate on a music change can cause a crash when loading the savestate