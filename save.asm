; SD2SNES Savestate code
; originally by acmlm, total, Myria
;

lorom

; Savestate code variables
!FREESPACE = $80F000 ; repoint to anywhere in banks $80-BF, $80 preferred
!RERANDOMIZE ?= 1 ; set to 0 to disable RNG randomization on loadstate
!SAVE_INPUTS = #$6010 ; Select + Y + R
!LOAD_INPUTS = #$6020 ; Select + Y + L
    ; Input Cheat Sheet
    ; $8000 = B
    ; $4000 = Y
    ; $2000 = Select
    ; $1000 = Start
    ; $0800 = Up
    ; $0400 = Down
    ; $0200 = Left
    ; $0100 = Right
    ; $0080 = A
    ; $0040 = X
    ; $0020 = L
    ; $0010 = R

!SS_INPUT_CUR = $8B
!SS_INPUT_NEW = $8F
!SS_INPUT_PREV = $97

!SRAM_DMA_BANK = $770000
!SRAM_SAVED_SP = $774004
!ram_room_has_set_rng = $7FFB00 ; can be any free RAM
!sram_save_has_set_rng = $702A00 ; can be any free SRAM in $70

; SM specific things
!SRAM_MUSIC_BANK = $701FD0
!SRAM_MUSIC_TRACK = $701FD2
!MUSIC_BANK = $07F3
!MUSIC_TRACK = $07F5
!MUSIC_ROUTINE = $808FC1


; Patch out copy protection
org $008000
    db $FF


; Set SRAM size
org $00FFD8
    db $08 ; 256kb


; ------------
; Input Checks
; ------------

; hijack main game loop for input checks
org $828963
    JSL gamemode_start : BCS end_of_normal_gameplay

org $82896E
    ; skip gamemode JSR if the current frame doesn't need to be processed any further
    end_of_normal_gameplay:

org !FREESPACE
print pc, " gamemode start"
gamemode_start:
{
    PHB
    PHK : PLB

    ; check for new inputs
    LDA !SS_INPUT_NEW : BNE +
    CLC : BRA .done

    ; check for savestate inputs
+   LDA !SS_INPUT_CUR : CMP !SAVE_INPUTS : BNE +
    AND !SS_INPUT_NEW : BEQ +
    JSL save_state
    SEC : BRA .done

    ; check for loadstate inputs
+   LDA !SS_INPUT_CUR : CMP !LOAD_INPUTS : BNE +
    AND !SS_INPUT_NEW : BEQ +
    JSL load_state
    SEC : BRA .done

    ; exit carry clear to continue normal gameplay
+   CLC

  .done
    REP #$30 ; ai16
    LDA $0998 : AND #$00FF
    PLB
    RTL
}
print pc, " gamemode end"


; ---------
; Save/Load
; ---------

SaveASM:
print pc, " save start"
; These can be modified to do game-specific things before and after saving and loading
; Both A and X/Y are 16-bit here

; SM specific features to restore the correct music when loading a state below
pre_load_state:
    LDA !MUSIC_BANK : STA !SRAM_MUSIC_BANK
    LDA !MUSIC_TRACK : STA !SRAM_MUSIC_TRACK

    ; Rerandomize
if !RERANDOMIZE
    LDA !sram_save_has_set_rng : BNE +
    LDA $05E5 : STA $770080
    LDA $05B6 : STA $770082
endif
+   RTS

post_load_state:
    ; If $05F5 is non-zero, the game won't clear the sounds
    LDA $05F5 : PHA
    STZ $05F5
    JSL $82BE17 ; Cancel sound effects
    PLA : STA $05F5

    ; Makes the game check Samus' health again, to see if we need annoying sound
    LDA #$0000 : STA $0A6A

    LDA !SRAM_MUSIC_BANK : CMP !MUSIC_BANK : BNE music_load_bank
    LDA !SRAM_MUSIC_TRACK : CMP !MUSIC_TRACK : BNE music_load_track
    BRA music_done

music_load_bank:
    LDA #$FF00 : CLC : ADC !MUSIC_BANK
    JSL !MUSIC_ROUTINE

music_load_track:
    LDA !MUSIC_TRACK
    JSL !MUSIC_ROUTINE

music_done:
    ; Rerandomize
if !RERANDOMIZE
    LDA !sram_save_has_set_rng : BNE +
    LDA $770080 : STA $05E5
    LDA $770082 : STA $05B6
endif
+   RTS


; These restored registers are game-specific and needs to be updated for different games
register_restore_return:
    SEP #$20 ; a8
    LDA $84 : STA $4200
    LDA #$0F : STA $13 : STA $2100
    RTL

save_state:
    PEA $0000
    PLB : PLB

    ; Store DMA registers to SRAM
    SEP #$20 ; a8
    LDY #$0000 : TYX

save_dma_regs:
    LDA $4300,X : STA !SRAM_DMA_BANK,X
    INX : INY
    CPY #$000B : BNE save_dma_regs
    CPX #$007B : BEQ save_dma_regs_done
    INX #5 : LDY #$0000
    BRA save_dma_regs

save_dma_regs_done:
    REP #$30 ; ai16
    LDX #save_write_table

run_vm:
    PHK : PLB
    JMP vm

save_write_table:
    ; Turn PPU off
    dw $1000|$2100, $80
    dw $1000|$4200, $00
    ; Single address, B bus -> A bus.  B address = reflector to WRAM ($2180).
    dw $0000|$4310, $8080  ; direction = B->A, byte reg, B addr = $2180
    ; Copy WRAM 7E0000-7E7FFF to SRAM 710000-717FFF.
    dw $0000|$4312, $0000  ; A addr = $xx0000
    dw $0000|$4314, $0071  ; A addr = $71xxxx, size = $xx00
    dw $0000|$4316, $0080  ; size = $80xx ($8000), unused bank reg = $00.
    dw $0000|$2181, $0000  ; WRAM addr = $xx0000
    dw $1000|$2183, $00    ; WRAM addr = $7Exxxx  (bank is relative to $7E)
    dw $1000|$420B, $02    ; Trigger DMA on channel 1
    ; Copy WRAM 7E8000-7EFFFF to SRAM 720000-727FFF.
    dw $0000|$4312, $0000  ; A addr = $xx0000
    dw $0000|$4314, $0072  ; A addr = $72xxxx, size = $xx00
    dw $0000|$4316, $0080  ; size = $80xx ($8000), unused bank reg = $00.
    dw $0000|$2181, $8000  ; WRAM addr = $xx8000
    dw $1000|$2183, $00    ; WRAM addr = $7Exxxx  (bank is relative to $7E)
    dw $1000|$420B, $02    ; Trigger DMA on channel 1
    ; Copy WRAM 7F0000-7F7FFF to SRAM 730000-737FFF.
    dw $0000|$4312, $0000  ; A addr = $xx0000
    dw $0000|$4314, $0073  ; A addr = $73xxxx, size = $xx00
    dw $0000|$4316, $0080  ; size = $80xx ($8000), unused bank reg = $00.
    dw $0000|$2181, $0000  ; WRAM addr = $xx0000
    dw $1000|$2183, $01    ; WRAM addr = $7Fxxxx  (bank is relative to $7E)
    dw $1000|$420B, $02    ; Trigger DMA on channel 1
    ; Copy WRAM 7F8000-7FFFFF to SRAM 740000-747FFF.
    dw $0000|$4312, $0000  ; A addr = $xx0000
    dw $0000|$4314, $0074  ; A addr = $74xxxx, size = $xx00
    dw $0000|$4316, $0080  ; size = $80xx ($8000), unused bank reg = $00.
    dw $0000|$2181, $8000  ; WRAM addr = $xx8000
    dw $1000|$2183, $01    ; WRAM addr = $7Fxxxx  (bank is relative to $7E)
    dw $1000|$420B, $02    ; Trigger DMA on channel 1
    ; Address pair, B bus -> A bus.  B address = VRAM read ($2139).
    dw $0000|$4310, $3981  ; direction = B->A, word reg, B addr = $2139
    dw $1000|$2115, $0000  ; VRAM address increment mode.
    ; Copy VRAM 0000-7FFF to SRAM 750000-757FFF.
    dw $0000|$2116, $0000  ; VRAM address >> 1.
    dw $9000|$2139, $0000  ; VRAM dummy read.
    dw $0000|$4312, $0000  ; A addr = $xx0000
    dw $0000|$4314, $0075  ; A addr = $75xxxx, size = $xx00
    dw $0000|$4316, $0080  ; size = $80xx ($0000), unused bank reg = $00.
    dw $1000|$420B, $02    ; Trigger DMA on channel 1
    ; Copy VRAM 8000-7FFF to SRAM 760000-767FFF.
    dw $0000|$2116, $4000  ; VRAM address >> 1.
    dw $9000|$2139, $0000  ; VRAM dummy read.
    dw $0000|$4312, $0000  ; A addr = $xx0000
    dw $0000|$4314, $0076  ; A addr = $76xxxx, size = $xx00
    dw $0000|$4316, $0080  ; size = $80xx ($0000), unused bank reg = $00.
    dw $1000|$420B, $02    ; Trigger DMA on channel 1
    ; Copy CGRAM 000-1FF to SRAM 772000-7721FF.
    dw $1000|$2121, $00    ; CGRAM address
    dw $0000|$4310, $3B80  ; direction = B->A, byte reg, B addr = $213B
    dw $0000|$4312, $2000  ; A addr = $xx2000
    dw $0000|$4314, $0077  ; A addr = $77xxxx, size = $xx00
    dw $0000|$4316, $0002  ; size = $02xx ($0200), unused bank reg = $00.
    dw $1000|$420B, $02    ; Trigger DMA on channel 1
    ; Done
    dw $0000, save_return

save_return:
    PEA $0000
    PLB : PLB

    REP #$30 ; ai16
    LDA !ram_room_has_set_rng : STA !sram_save_has_set_rng

    TSC : STA !SRAM_SAVED_SP
    JMP register_restore_return


load_state:
    JSR pre_load_state
    PEA $0000
    PLB : PLB

    SEP #$20 ; a8
    LDX #load_write_table
    JMP run_vm

load_write_table:
    ; Disable HDMA
    dw $1000|$420C, $00
    ; Turn PPU off
    dw $1000|$2100, $80
    dw $1000|$4200, $00
    ; Single address, A bus -> B bus.  B address = reflector to WRAM ($2180).
    dw $0000|$4310, $8000  ; direction = A->B, B addr = $2180
    ; Copy SRAM 710000-717FFF to WRAM 7E0000-7E7FFF.
    dw $0000|$4312, $0000  ; A addr = $xx0000
    dw $0000|$4314, $0071  ; A addr = $71xxxx, size = $xx00
    dw $0000|$4316, $0080  ; size = $80xx ($8000), unused bank reg = $00.
    dw $0000|$2181, $0000  ; WRAM addr = $xx0000
    dw $1000|$2183, $00    ; WRAM addr = $7Exxxx  (bank is relative to $7E)
    dw $1000|$420B, $02    ; Trigger DMA on channel 1
    ; Copy SRAM 720000-727FFF to WRAM 7E8000-7EFFFF.
    dw $0000|$4312, $0000  ; A addr = $xx0000
    dw $0000|$4314, $0072  ; A addr = $72xxxx, size = $xx00
    dw $0000|$4316, $0080  ; size = $80xx ($8000), unused bank reg = $00.
    dw $0000|$2181, $8000  ; WRAM addr = $xx8000
    dw $1000|$2183, $00    ; WRAM addr = $7Exxxx  (bank is relative to $7E)
    dw $1000|$420B, $02    ; Trigger DMA on channel 1
    ; Copy SRAM 730000-737FFF to WRAM 7F0000-7F7FFF.
    dw $0000|$4312, $0000  ; A addr = $xx0000
    dw $0000|$4314, $0073  ; A addr = $73xxxx, size = $xx00
    dw $0000|$4316, $0080  ; size = $80xx ($8000), unused bank reg = $00.
    dw $0000|$2181, $0000  ; WRAM addr = $xx0000
    dw $1000|$2183, $01    ; WRAM addr = $7Fxxxx  (bank is relative to $7E)
    dw $1000|$420B, $02    ; Trigger DMA on channel 1
    ; Copy SRAM 740000-747FFF to WRAM 7F8000-7FFFFF.
    dw $0000|$4312, $0000  ; A addr = $xx0000
    dw $0000|$4314, $0074  ; A addr = $74xxxx, size = $xx00
    dw $0000|$4316, $0080  ; size = $80xx ($8000), unused bank reg = $00.
    dw $0000|$2181, $8000  ; WRAM addr = $xx8000
    dw $1000|$2183, $01    ; WRAM addr = $7Fxxxx  (bank is relative to $7E)
    dw $1000|$420B, $02    ; Trigger DMA on channel 1
    ; Address pair, A bus -> B bus.  B address = VRAM write ($2118).
    dw $0000|$4310, $1801  ; direction = A->B, B addr = $2118
    dw $1000|$2115, $0000  ; VRAM address increment mode.
    ; Copy SRAM 750000-757FFF to VRAM 0000-7FFF.
    dw $0000|$2116, $0000  ; VRAM address >> 1.
    dw $0000|$4312, $0000  ; A addr = $xx0000
    dw $0000|$4314, $0075  ; A addr = $75xxxx, size = $xx00
    dw $0000|$4316, $0080  ; size = $80xx ($0000), unused bank reg = $00.
    dw $1000|$420B, $02    ; Trigger DMA on channel 1
    ; Copy SRAM 760000-767FFF to VRAM 8000-7FFF.
    dw $0000|$2116, $4000  ; VRAM address >> 1.
    dw $0000|$4312, $0000  ; A addr = $xx0000
    dw $0000|$4314, $0076  ; A addr = $76xxxx, size = $xx00
    dw $0000|$4316, $0080  ; size = $80xx ($0000), unused bank reg = $00.
    dw $1000|$420B, $02    ; Trigger DMA on channel 1
    ; Copy SRAM 772000-7721FF to CGRAM 000-1FF.
    dw $1000|$2121, $00    ; CGRAM address
    dw $0000|$4310, $2200  ; direction = A->B, byte reg, B addr = $2122
    dw $0000|$4312, $2000  ; A addr = $xx2000
    dw $0000|$4314, $0077  ; A addr = $77xxxx, size = $xx00
    dw $0000|$4316, $0002  ; size = $02xx ($0200), unused bank reg = $00.
    dw $1000|$420B, $02    ; Trigger DMA on channel 1
    ; Done
    dw $0000, load_return

load_return:
    REP #$30 ; ai16
    LDA !SRAM_SAVED_SP : TCS

    PEA $0000
    PLB : PLB

    ; rewrite inputs so that holding load won't keep loading, as well as rewriting saving input to loading input
    LDA !SS_INPUT_CUR : EOR !SAVE_INPUTS : ORA !LOAD_INPUTS
    STA !SS_INPUT_CUR : STA !SS_INPUT_NEW : STA !SS_INPUT_PREV

    SEP #$20 ; a8
    LDX #$0000 : TXY

load_dma_regs:
    LDA !SRAM_DMA_BANK,X
    STA $4300,X
    INX : INY
    CPY #$000B : BNE load_dma_regs
    CPX #$007B : BEQ load_dma_regs_done
    INX #5 : LDY #$0000
    JMP load_dma_regs

load_dma_regs_done:
    ; Restore registers and return.
    REP #$30 ; ai16
    JSR post_load_state
    JMP register_restore_return

vm:
    ; Data format: xx xx yy yy
    ; xxxx = little-endian address to write to .vm's bank
    ; yyyy = little-endian value to write
    ; If xxxx has high bit set, read and discard instead of write.
    ; If xxxx has bit 12 set ($1000), byte instead of word.
    ; If yyyy has $DD in the low half, it means that this operation is a byte
    ; write instead of a word write.  If xxxx is $0000, end the VM.
    REP #$30 ; ai16
    ; Read address to write to
    LDA.w $0000,X : BEQ vm_done
    TAY
    INX #2
    ; Check for byte mode
    BIT.w #$1000 : BEQ vm_word_mode
    AND.w #$EFFF : TAY
    SEP #$20 ; a8
vm_word_mode:
    ; Read value
    LDA.w $0000,X
    INX #2
vm_write:
    ; Check for read mode (high bit of address)
    CPY.w #$8000 : BCS vm_read
    STA $0000,Y
    BRA vm
vm_read:
    ; "Subtract" $8000 from Y by taking advantage of bank wrapping.
    LDA $8000,Y
    BRA vm

vm_done:
    ; A, X and Y are 16-bit at exit.
    ; Return to caller.  The word in the table after the terminator is the
    ; code address to return to.
    JMP ($0002,x)

print pc, " save end"


; -----------
; RNG Seeders
; -----------

if !RERANDOMIZE
pushpc

; Don't rerandomize if enemy seeds RNG
org $A3AB12
    JSL hook_hopper_set_rng

org $A2B588
    JSL hook_lavarocks_set_rng
    NOP #2

org $A8B798
    JSL hook_beetom_set_rng
    NOP #2

pullpc

print pc, " rng start"
hook_hopper_set_rng:
    LDA #$0001 : STA !ram_room_has_set_rng
    JML $808111

hook_lavarocks_set_rng:
    LDA #$0001 : STA !ram_room_has_set_rng
    LDA #$0011 : STA $05E5
    RTL

hook_beetom_set_rng:
    LDA #$0001 : STA !ram_room_has_set_rng
    LDA #$0017 : STA $05E5
    RTL
print pc, " rng end"
endif


pushpc

; hijack, runs as game is starting, JSR to RAM initialization to avoid bad values
org $808455
    JML init_code

pullpc

init_code:
    REP #$30 ; ai16
    PHA
    LDA #$0000
    STA !sram_save_has_set_rng : STA !ram_room_has_set_rng
    PLA
    JSL $8B9146 ; overwritten code
    JML $808459 ; return

