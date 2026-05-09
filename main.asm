cycle equ 30h       ; 0=incrementing, 1=decrementing

org 0000h
    ljmp Main
org 000Bh
    ljmp T0_ISR
org 0023h
    ljmp serial_port_isr

org 0040h
Main:
DIV_H   DATA 20H
DIV_L   DATA 21H
DVSR_H  DATA 02h
DVSR_L  DATA 03h
QUOT_H  DATA 24H
QUOT_L  DATA 25H
REM_H   DATA 26H
REM_L   DATA 27H

    mov p1,  #00h
    mov r0,  #00h
    mov cycle, #00h

    ; 19608 = 1 / (0.5us x 102), so (256-count) = 19608/f
    mov 20h, #4ch
    mov 21h, #98h

    mov pcon, #80h          ; SMOD=1: double baud rate
    mov tmod, #22h          ; Timer1 and Timer0 both mode 2 (auto-reload)
    mov th1,  #(256-7)      ; 19200 baud at 11.0592MHz with SMOD=1
    mov tl1,  th1
    mov scon, #50h          ; UART mode 1, REN=1

    mov th0, #1
    mov tl0, th0

    setb tr1
    setb tr0
    setb ea
    setb et0
    setb es
    setb ps                 ; serial ISR priority over Timer0

waiting: sjmp waiting

org 0100h
T0_ISR:
    push acc
    push psw
    mov a, r0
    mov p1, a               ; output to DAC

    jb cycle, Decrement
    cjne r0, #255, Exit
    setb cycle
    mov r0, #250
    sjmp Final_Exit
Exit:
    add a, #5
    mov r0, a
    sjmp Final_Exit

Decrement:
    cjne r0, #00h, Dec_Exit
    clr cycle
    mov r0, #05
    sjmp Final_Exit
Dec_Exit:
    clr c
    subb a, #5
    mov r0, a
Final_Exit:
    pop psw
    pop acc
    reti

org 0200h
serial_port_isr:
    push acc
    push psw
    mov b, sbuf
    mov r2, b
    clr ri
Serial_Jump_2:
    jnb ri, Serial_Jump_2
    mov b, sbuf
    mov r3, b
    clr ri
    acall Divider_Routine
    mov a, 25h
    cpl a                   ; two's complement negation → (256 - count)
    mov 25h, a
    inc 25h
    mov th0, 25h
    mov tl0, th0
    pop psw
    pop acc
    reti

org 0300h
Divider_Routine:
    ; restoring division: 19608 / frequency, result in QUOT_H:QUOT_L
    ; remainder discarded — higher remainder → larger frequency error
    MOV QUOT_H, #0
    MOV QUOT_L, #0
    MOV REM_H,  #0
    MOV REM_L,  #0
    MOV DIV_H,  #4Ch
    MOV DIV_L,  #98H
    CLR C
    MOV R7, #16

DIV_LOOP:
    MOV A, DIV_L
    RLC A
    MOV DIV_L, A
    MOV A, DIV_H
    RLC A
    MOV DIV_H, A

    MOV A, REM_L
    RLC A
    MOV REM_L, A
    MOV A, REM_H
    RLC A
    MOV REM_H, A

    CLR C
    MOV A, REM_H
    SUBB A, DVSR_H
    JC NO_SUBTRACT
    JNZ subtract
    MOV A, REM_L
    CLR C
    SUBB A, DVSR_L
    JC NO_SUBTRACT

subtract:
    MOV A, REM_L
    CLR C
    SUBB A, DVSR_L
    MOV REM_L, A
    MOV A, REM_H
    SUBB A, DVSR_H
    MOV REM_H, A
    SETB C
    MOV A, QUOT_L
    RLC A
    MOV QUOT_L, A
    MOV A, QUOT_H
    RLC A
    MOV QUOT_H, A
    SJMP NEXT_BIT

NO_SUBTRACT:
    CLR C
    MOV A, QUOT_L
    RLC A
    MOV QUOT_L, A
    MOV A, QUOT_H
    RLC A
    MOV QUOT_H, A

NEXT_BIT:
    DJNZ R7, DIV_LOOP
    RET

end