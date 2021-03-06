global main
global random
global myexit
global startFunc
global endFunc
global printInt
global int_format
global N
global K
global R
global COs
global resume
global endCo
global seed
global _360
global MAXINT
global CURRDRONE
global drones
global targetX
global targetY
global numOfActiveDrones
global CURR
global d
global BOARDSIZE
global float_format
extern malloc 
extern calloc 
extern free 
extern sscanf
extern printf
extern droneFunc
extern targetFunc
extern printerFunc
extern schedulerFunc
section	.rodata         ;constats
    int_format: db "%d", 10, 0	; format string
    float_format: db "%2f",10,0
    hexa_format: db "%X",10,0
    argc_unmached: db "ERROR- 5 args is needed",10,0
    atleast2drones: db "ERROR- 'N' should be at least 2",10,0

    MAXINT: dd 65535
    BOARDSIZE: dd 100
    _360: dd 360
    STKSIZE equ 16*1024 
    CODEP equ 0         ; offset of pointer to co-routine function in co-routine struct
    SPP equ 4           ; offset of pointer to co-routine stack in co-routine struct 

section .data           ; inisiliazed vars
section .bss            ; uninitilaized vars
    N: resd 1       ;number of drones
    R: resd 1       ;number of full scheduler cycles between each elimination
    K: resd 1       ;how many drone steps between game board printings
    d: resq 1       ;maximum distance that allows to destroy a target
    seed: resd 1    ;seed for initialization of LFSR shift register
    drones: resd 1  ;drones database
    COs: resd 1     ;co-routine array
    CURR: resd 1
    SPT: resd 1     ; temporary stack pointer
    SPMAIN: resd 1  ; stack pointer of main
    CURRDRONE: resd 1
    targetX: resq 1
    targetY: resq 1
    stacksHolder: resd 1
    numOfActiveDrones: resd 1
%macro	syscall1 2
	mov	ebx, %2
	mov	eax, %1
	int	0x80
%endmacro
%macro  exit 1
	syscall1 SIGEXIT, %1
%endmacro
%macro errorExit 1
    push dword %1
    call printf
    exit -1
%endmacro
%macro my_sscanf1 3 
    pushad
    ;%1 == format ;%2 == read to
    push dword %3
    push dword %2
    push dword %1
    call sscanf
    add esp, 12
    popad
%endmacro
%macro printInt 1
    pushad
    push dword %1
    push int_format
    call printf
    add esp, 8
    popad
%endmacro
%macro printFloat 1
    ;%1 is a pointer to the float
    pushad
    push dword [%1+4]
    push dword [%1]
    push float_format
    call printf
    add esp, 12
    popad
%endmacro
%macro printHexa 1
    pushad
    push dword %1
    push hexa_format
    call printf
    add esp, 8
    popad
%endmacro
%macro startFunc 1
    push ebp
    mov ebp, esp
    sub esp, %1
%endmacro
%macro endFunc 1
    add esp, %1
    mov esp, ebp
    pop ebp
    ret
%endmacro
%macro myMalloc 1
    ;ret value in eax
    push ebx
    push ecx
    push edx              
    push dword %1
    call malloc
    add esp, 4
    pop edx
    pop ecx
    pop ebx
%endmacro
%macro myCalloc 2
    ;%1 num of units ;%2 size of unit
    ;ret value in eax
    push ebx
    push ecx
    push edx              
    push dword %2
    push dword %1
    call calloc
    add esp, 8
    pop edx
    pop ecx
    pop ebx
%endmacro
%macro myFree 1
    ;ret value in eax
    push ebx
    push ecx
    push edx              
    push dword %1
    call free
    add esp, 4
    pop edx
    pop ecx
    pop ebx
%endmacro
%define EXIT_SUCCESS 0
%define SIGEXIT 1
%define X 0
%define Y 8
%define angle 16
%define speed 24
%define score 32
%define active 36
%define droneSize 40


section .text
main:
    finit                       ;initilize x87
    mov eax, [esp+4]            ; argc
    cmp eax, 6                  ; argc ?== 6 (filename + 5 args)
    je .parseArgs
    errorExit argc_unmached
    .parseArgs:
    mov eax, [esp+8]            ;eax <- argv
    mov ebx, [eax+4]            ;ebx <- argv[1]
    my_sscanf1 ebx, int_format, N
    mov edx, [N]
    mov [numOfActiveDrones], edx
    cmp edx, 2
    jge .continue
    errorExit atleast2drones
    .continue:
    mov ebx, [eax+8]            ;ebx <- argv[2]
    my_sscanf1 ebx, int_format, R
    mov ebx, [eax+12]            ;ebx <- argv[3]
    my_sscanf1 ebx, int_format, K
    mov ebx, [eax+16]            ;ebx <- argv[4]
    my_sscanf1 ebx, int_format, d
    fild dword [d]               ;convert to float
    fstp qword [d]
    mov ebx, [eax+20]            ;ebx <- argv[5]
    my_sscanf1 ebx, int_format, seed
    ;###### malloc drones data base#######
    myCalloc [N], droneSize
    mov [drones], eax
    ;####### init drones data base####
        mov ecx, [N]
        .initDronesLoop:
        mov eax, ecx
        dec eax
        mov edx , droneSize
        mul edx
        mov ebx, [drones]
        add ebx, eax
        ;set X
        pushad
        call random
        popad
        fild dword [seed]
        fild dword [MAXINT]
        fdivp
        fimul dword [BOARDSIZE]
        fstp qword [ebx+X]
        ;set Y
        pushad
        call random
        popad
        fild dword [seed]
        fild dword [MAXINT]
        fdivp
        fimul dword [BOARDSIZE]
        fstp qword [ebx+Y]
        ;set angle
        pushad
        call random
        popad
        fild dword [seed]
        fild dword [MAXINT]
        fdivp
        fimul dword [_360]
        fstp qword [ebx+angle]
        ;set speed
        pushad
        call random
        popad
        fild dword [seed]
        fild dword [MAXINT]
        fdivp
        fimul dword [BOARDSIZE]
        fstp qword [ebx+speed]
        ;set score for debuging
            ; mov [ebx+score], ecx
        ;set activnse to 1 (true)
        mov [ebx+active], dword 1
                                            ; printFloat ebx+X
                                            ; printFloat ebx+Y
                                            ; printFloat ebx+angle
                                            ; printFloat ebx+speed
                                            ; printInt [ebx+score]     
                                            ; printInt [ebx+active]
        ; loop .activeLoop, ecx
        dec ecx
        cmp ecx, 0
        jne .initDronesLoop

    ;####init target######
    call random
    fild dword [seed]
    fild dword [MAXINT]
    fdivp
    fimul dword [BOARDSIZE]
    fstp qword [targetX]
    call random
    fild dword [seed]
    fild dword [MAXINT]
    fdivp
    fimul dword [BOARDSIZE]
    fstp qword [targetY]
    ;###### malloc co-rutine database#######
    mov ecx, [N]
    add ecx, 3          
    myCalloc ecx, 8     ;each CO has 4 bytes points to STACK and 4 bytes points function
    mov [COs], eax
    myCalloc ecx, 4
    mov [stacksHolder], eax
    .allocateStackLoop: ;ecx is index
    myMalloc STKSIZE
    mov ebx, [stacksHolder]
    mov [ebx + 4*(ecx-1)], eax ;stacksHolder[i]<- start of stack
    mov ebx, [COs]
    add eax, STKSIZE
    mov [ebx+ 8*(ecx-1)+SPP], eax   ;COs[i]<- end of stack
    mov [ebx+ 8*(ecx-1)+CODEP], dword droneFunc   ;a temppurery function addressד
    loop .allocateStackLoop, ecx
    ;###########place target,printer, schduler in place######
    ;COs[N]<-target; COs[N+1]<-printer ;COs[N+2]<-scheduler
    mov ecx, [N]
    mov [ebx+ 8*ecx+CODEP], dword targetFunc   ;a temppurery function addressד
    inc ecx
    mov [ebx+ 8*ecx+CODEP], dword printerFunc   ;a temppurery function addressד
    inc ecx
    mov [ebx+ 8*ecx+CODEP], dword schedulerFunc   ;a temppurery function addressד
    ;####### initCOs ######
    mov ecx, [N]
    add ecx, 3
    .initLoop:
    mov  ebx, ecx   ;this line and the line below is just becuse i couldnt do "push (ecx-1)""
    dec ebx
    push  ebx   ;push co's index
    call initCo    
    add esp, 4  ;silent pop
    loop .initLoop, ecx
    ;######## call scheduler######
    mov ecx, [N]
    add ecx, 2
    push ecx
    call startCo
    

myexit:
myFree [drones]
mov ecx, [N]
add ecx, 3          
.freeStackLoop: ;ecx is index
    mov ebx, [stacksHolder]
    mov eax, [ebx+ 4*(ecx-1)]   ;put the ball in the sal
    myFree eax
loop .freeStackLoop, ecx
myFree [COs]
myFree [stacksHolder]
exit EXIT_SUCCESS

initCo: ;gets one argument which is CO index
    startFunc 0
    mov ebx, [COs]
    mov eax, [ebp+8]    ;eax <- co-routine ID number
    mov edx, 8
    mul edx
    add ebx, eax    ;ebx <- co's struct
    mov eax, ebx +CODEP ;eax <- func first instruction
    mov [SPT], esp      ;backup main's esp
    mov esp, [ebx+SPP]  ;esp <- co's stack position
    push dword [eax]            ;save func pointer on co's stack
    pushfd
    pushad
    mov [ebx+SPP], esp  ;save co's new stack postion
    mov esp, [SPT]      ;restore main's stack pointer
    endFunc 0
    
random:
    ;ax holds old number, ecx is an index, ebx is mask, edx accumlate xors
    startFunc 0
    mov eax, 0
    mov ax ,[seed]
    mov ecx, 16
    .shift:
    mov bx, 1       ;00...0001
    and bx, ax      ;mask
    mov dx, bx      
    mov bx, 4       ;00...0100
    and bx, ax      ;mask
    shr bx, 2       ;put in lsb
    xor dx, bx
    mov bx, 8       ;00...1000
    and bx, ax      ;mask
    shr bx, 3       ;put in lsb
    xor dx, bx
    mov bx, 32      ;0...100000
    and bx, ax      ;mask
    shr bx, 5       ;put in lsb
    xor dx, bx
    ;put the ball in the sal
    shl dx, 15
    shr ax, 1
    or  ax, dx
    loop .shift, ecx
    mov [seed], ax
    ; printHexa eax
    endFunc 0

resume:
    pushfd
    pushad
    mov edx, [CURR]     
    mov [edx+SPP], esp     
do_resume:
    mov esp , [ebx+SPP]     ;load CO's stack
    mov [CURR], ebx         ;CURR<- CO's
    popad                   ;load registers
    popfd                   ;load flags
    ;debug
    ; pop eax
    ; printInt eax
    ; printInt [schedulerFunc]
    ;debug
    ret

startCo:
    startFunc 0
    pushad
    mov [SPMAIN], esp
    mov ebx, [COs]
    mov eax, [ebp+8]    ;eax <- co-routine ID number
    mov edx, 8
    mul edx             ;eax <- co's 8*ID
    add ebx, eax    ;ebx <- co's struct address
    jmp do_resume   ;call scheduler's CO
endCo:
    mov ESP, [SPMAIN] ; restore ESP of main()
    popad ; restore registers of main()
    endFunc 0
