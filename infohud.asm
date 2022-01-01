;=======================================================
;InfoHUD timers and stuff
;=======================================================

org $008000      ; Patch out copy protection
    db $FF

org $828B4B      ; disable debug functions
    JML ih_debug_patch

org $808438      ; hijack, runs as game is starting, JSR to RAM initialization to avoid bad values
    JML init_code

org $828B34      ; reset room timers for first room of Ceres
    JML ceres_start_timers : NOP #2 : ceres_start_timers_return:

org $9493FB      ; hijack, runs when Samus hits a door BTS
    JSL ih_before_room_transition

org $9493B8      ; hijack, runs when Samus hits a door BTS
    JSL ih_before_room_transition

org $82E75E      ; hijack, runs when Samus is coming out of a room transition
    JML ih_after_room_transition

org $84889F      ; hijack, runs every time an item is picked up
    JSL ih_get_item_code

org $8095F4      ; hijack, end of NMI routine to update realtime frames
    JML ih_nmi_end

org $80A16B      ; Adds frames when unpausing (nmi is turned off during vram transfers)
    JSL hook_unpause

org $90F1E4      ; update timers when an elevator is activated
    JSL ih_elevator_activation

org $A98874      ; update timers after MB1 fight
    JSL ih_mb1_segment

org $A9BE23      ; update timers when baby spawns (off-screen) in MB2 fight
    JSL ih_mb2_segment

org $A0B9AE      ; update timers when Ridley drops spawn
    JSL ih_drops_segment

org $A0B9E1      ; update timers when Crocomire drops spawn
    JSL ih_drops_segment

org $A0BA14      ; update timers when Phantoon drops spawn
    JSL ih_drops_segment

org $A0BA47      ; update timers when Botwoon drops spawn
    JSL ih_drops_segment

org $A0BA7A      ; update timers when Kraid drops spawn
    JSL ih_drops_segment

org $A0BAAD      ; update timers when Bomb Torizo drops spawn
    JSL ih_drops_segment

org $A0BAE0      ; update timers when Golden Torizo drops spawn
    JSL ih_drops_segment

org $A0BB13      ; update timers when Spore Spawn drops spawn
    JSL ih_drops_segment

org $A0BB46      ; update timers when Draygon drops spawn
    JSL ih_drops_segment

org $AAE582      ; update timers when statue grabs Samus
    JSL ih_chozo_segment

org $89AD0A      ; update timers when Samus escapes Ceres
    JSL ih_ceres_elevator_segment

org $A2AA20      ; update timers when Samus enters ship
    JSL ih_ship_elevator_segment


; Main bank stuff
org $9DFD00
print pc, " infohud start"

ih_get_item_code:
{
    PHA
    LDA !ram_realtime_room : STA !ram_last_realtime_room

    ; save temp variables
    LDA $12 : PHA
    LDA $14 : PHA

    ; Update HUD
    JSL ih_update_hud_code

    ; restore temp variables
    PLA : STA $14
    PLA : STA $12

    PLA
    JSL $80818E
    RTL
}

ih_debug_patch:
{
    LDA $05D1
    BNE +
    JML $828B54
+   JSL $B49809
    JML $828B4F
}

ih_nmi_end:
{
    %ai16()

    LDA !ram_realtime_room : INC : STA !ram_realtime_room

  .done
    REP #$30
    INC $05B8
    JML $8095F9
}

ih_after_room_transition:
{
    PHX
    PHY

    LDA #$0000 : STA !ram_transition_flag

    ; Update HUD
    JSL ih_update_hud_code

    ; Reset realtime timer
    LDA #$0000 : STA !ram_realtime_room

    PLY
    PLX

    ; original hijacked code
    STZ $0795
    STZ $0797
    JML $82E764
}

ih_before_room_transition:
{
    PHA
    PHX
    PHY

    ; Save and reset timers
    LDA !ram_transition_flag : CMP #$0001 : BEQ .done
    LDA #$0001 : STA !ram_transition_flag
if !FEATURE_SD2SNES
    LDA #$0000 : STA !ram_room_has_set_rng
endif

    ; Realtime
    LDA !ram_realtime_room : STA !ram_last_realtime_room
    LDA #$0000 : STA !ram_realtime_room

    ; Save temp variables
    LDA $12 : PHA
    LDA $14 : PHA

    ; Update HUD
    JSL ih_update_hud_code

    ; Restore temp variables
    PLA : STA $14
    PLA : STA $12

  .done
    ; Run standard code and return
    PLY
    PLX
    PLA
    STA $0998
    CLC
    RTL
}

hook_unpause:
{
    ; RT room
    LDA !ram_realtime_room : CLC : ADC.w #41 : STA !ram_realtime_room

  .done
    ; $80:A16B 22 4B 83 80 JSL $80834B[$80:834B]
    ; Replace overwritten logic to enable NMI
    JSL $80834B
    RTL
}

ceres_start_timers:
{
    LDA #$0000
    STA !ram_realtime_room : STA !ram_last_realtime_room

    STZ $0723 ; overwritten code
    STZ $0725
    
    JML ceres_start_timers_return
}

ih_elevator_activation:
{
    PHA
    ; Only update if we're in a room and activate an elevator.
    ; Otherwise this will also run when you enter a room already riding one.
    LDA $0998 : CMP #$0008 : BNE .done

    JSL ih_update_hud_early

  .done
    PLA
    STZ $0A56
    SEC
    RTL
}

ih_mb1_segment:
{
    ; runs during MB1 cutscene when you regain control of Samus, just before music change
    JSL $90F084 ; overwritten code

    JML ih_update_hud_early
}

ih_mb2_segment:
{
    ; runs during baby spawn routine for MB2
    STA $7E7854    ; we overwrote this instruction to get here

    JML ih_update_hud_early
}

ih_drops_segment:
{
    ; runs when boss drops spawn
    JSL ih_update_hud_early
    JML $808111 ; overwritten code
}

ih_chozo_segment:
{
    JSL $8090CB ; overwritten code
    JML ih_update_hud_early
}

ih_ceres_elevator_segment:
{
    JSL ih_update_hud_early
    JML $90F084 ; overwritten code
}

ih_ship_elevator_segment:
{
    JSL ih_update_hud_early
    JML $91E3F6 ; overwritten code
}

ih_update_hud_code:
{
    PHX
    PHY
    PHP
    PHB
    ; Bank 80
    PEA $8080 : PLB : PLB

    ; Real time
    ; Divide real time by 60/50, save seconds, frame seperately
    STZ $4205
    LDA !ram_last_realtime_room : STA $4204
    %a8()
    LDA #$3C : STA $4206
    PHA : PLA : PHA : PLA
    %a16()
    LDA $4214 : STA !ram_tmp_1
    LDA $4216 : STA !ram_tmp_2

    ; Draw seconds
    LDA !ram_tmp_1 : LDX #$00AE : JSR Draw3

    ; Draw decimal seperator
    LDA !IH_DECIMAL : STA $7EC6B4

    ; Draw frames
    LDA !ram_tmp_2 : ASL : TAX
    LDA HexToNumberGFX1,X : STA $7EC6B6
    LDA HexToNumberGFX2,X : STA $7EC6B8

  .end
    PLB
    PLP
    PLY
    PLX
    RTL
}

ih_update_hud_early:
{
    PHA
    PHX
    PHY

    LDA !ram_realtime_room : STA !ram_last_realtime_room

    ; save temp variables
    LDA $12 : PHA
    LDA $14 : PHA

    ; Update HUD
    JSL ih_update_hud_code

    ; restore temp variables
    PLA : STA $14
    PLA : STA $12

    ; Run standard code and return
    PLY
    PLX
    PLA
    RTL
}

;---SUBROUTINES---
Draw3:
{
    STA $4204
    %a8()
    LDA #$0A : STA $4206   ; divide by 10
    %a16()
    PEA $0000 : PLA
    LDA $4214 : STA $16

    ; Ones digit
    LDA $4216 : ASL : TAY : LDA.w NumberGFXTable,Y : STA $7EC604,X

    LDA $16 : BEQ .blanktens
    STA $4204
    %a8()
    LDA #$0A : STA $4206   ; divide by 10
    %a16()
    PEA $0000 : PLA
    LDA $4214 : STA $14

    ; Tens digit
    LDA $4216 : ASL : TAY : LDA.w NumberGFXTable,Y : STA $7EC602,X

    ; Hundreds digit
    LDA $14 : BEQ .blankhundreds : ASL : TAY : LDA.w NumberGFXTable,Y : STA $7EC600,X

  .done
    INX #6
    RTS

  .blanktens
    LDA !IH_BLANK : STA $7EC600,X : STA $7EC602,X
    BRA .done

  .blankhundreds
    LDA !IH_BLANK : STA $7EC600,X
    BRA .done
}

print pc, " infohud end"

org $81FE00
print pc, " init start"

init_code:
{
    PHP : REP #$30
    PHA
if !FEATURE_SD2SNES
    LDA #$0000 : STA !sram_save_has_set_rng
    STA !sram_ctrl_load_state : STA !sram_ctrl_save_state
endif

    LDA #$0000
    LDX !WRAM_SIZE-2
-   STA !WRAM_START,X
    DEX : DEX : BPL -

    PLA
    PLP
    ; Execute overwritten logic and return
    SEP #$30
    LDX #$04
    JML $80843C
}

print pc, " init end"
warnpc $81FF00


; Stuff that needs to be placed in bank $80
org !ROOMTIMER_BANK80
print pc, " infohud bank80 start"

NumberGFXTable: ; includes double digit tiles
    dw #$0C09, #$0C00, #$0C01, #$0C02, #$0C03, #$0C04, #$0C05, #$0C06, #$0C07, #$0C08
    dw #$0C70, #$0C71, #$0C72, #$0C73, #$0C74, #$0C75, #$0C78, #$0C79, #$0C7A, #$0C7B
    dw #$0C7C, #$0C7D, #$0C7E, #$0C7F, #$0CD2, #$0CD4, #$0CD5, #$0CD6, #$0CD7, #$0CD8
    dw #$0CD9, #$0CDA, #$0CDB, #$0C5C, #$0C5D, #$0CB8, #$0C8D, #$0C12, #$0C13, #$0C14
    dw #$0C15, #$0C16, #$0C17, #$0C18, #$0C19, #$0C1A, #$0C1B, #$0C20, #$0C21, #$0C22
    dw #$0C23, #$0C24, #$0C25, #$0C26, #$0C27, #$0C28, #$0C29, #$0C2A, #$0C2B, #$0C2C
    dw #$0C2D, #$0C2E, #$0C2F, #$0C30, #$0C31, #$0CCA

HexToNumberGFX1: ; tens digit
    dw #$0C09, #$0C09, #$0C09, #$0C09, #$0C09, #$0C09, #$0C09, #$0C09, #$0C09, #$0C09
    dw #$0C00, #$0C00, #$0C00, #$0C00, #$0C00, #$0C00, #$0C00, #$0C00, #$0C00, #$0C00
    dw #$0C01, #$0C01, #$0C01, #$0C01, #$0C01, #$0C01, #$0C01, #$0C01, #$0C01, #$0C01
    dw #$0C02, #$0C02, #$0C02, #$0C02, #$0C02, #$0C02, #$0C02, #$0C02, #$0C02, #$0C02
    dw #$0C03, #$0C03, #$0C03, #$0C03, #$0C03, #$0C03, #$0C03, #$0C03, #$0C03, #$0C03
    dw #$0C04, #$0C04, #$0C04, #$0C04, #$0C04, #$0C04, #$0C04, #$0C04, #$0C04, #$0C04

HexToNumberGFX2: ; ones digit
    dw #$0C09, #$0C00, #$0C01, #$0C02, #$0C03, #$0C04, #$0C05, #$0C06, #$0C07, #$0C08
    dw #$0C09, #$0C00, #$0C01, #$0C02, #$0C03, #$0C04, #$0C05, #$0C06, #$0C07, #$0C08
    dw #$0C09, #$0C00, #$0C01, #$0C02, #$0C03, #$0C04, #$0C05, #$0C06, #$0C07, #$0C08
    dw #$0C09, #$0C00, #$0C01, #$0C02, #$0C03, #$0C04, #$0C05, #$0C06, #$0C07, #$0C08
    dw #$0C09, #$0C00, #$0C01, #$0C02, #$0C03, #$0C04, #$0C05, #$0C06, #$0C07, #$0C08
    dw #$0C09, #$0C00, #$0C01, #$0C02, #$0C03, #$0C04, #$0C05, #$0C06, #$0C07, #$0C08

print pc, " infohud bank80 end"
warnpc $80FFC0 ; header

