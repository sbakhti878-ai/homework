extern interrupt_handler  ; Tell ASM that this function exists in C++ code

; -----------------------------------------------------------------------------
; Macro: isr_err
; Used for exceptions where the CPU automatically pushes an Error Code.
; Example: Page Fault (Vector 14)
; -----------------------------------------------------------------------------
%macro isr_err 1
isr_%+%1:
    ; CPU has already pushed: EFLAGS, CS, EIP, Error Code
    push dword %1               ; Push the Interrupt Number (so C++ knows which one it is)
    jmp common_interrupt_handler ; Jump to the shared code
%endmacro

; -----------------------------------------------------------------------------
; Macro: isr_no_err
; Used for interrupts where the CPU does NOT push an Error Code.
; Example: Keyboard Interrupt (Vector 33)
; -----------------------------------------------------------------------------
%macro isr_no_err 1
isr_%+%1:
    ; CPU has already pushed: EFLAGS, CS, EIP
    push dword 0                ; Push a dummy error code (0) to keep stack consistent
    push dword %1               ; Push the Interrupt Number
    jmp common_interrupt_handler
%endmacro

; -----------------------------------------------------------------------------
; Common Interrupt Handler
; Saves the entire CPU state, calls C++ code, and restores state.
; -----------------------------------------------------------------------------
common_interrupt_handler:
    pushad          ; Push all General Purpose Registers (EAX, ECX, EDX, EBX, ESP, EBP, ESI, EDI)
                    ; This creates the 'cpu_state' struct on the stack.

    ; --- SETUP POINTERS FOR C++ ---
    ; To avoid copying large structures and corrupting the stack, we pass POINTERS.
    ; Stack layout right now (growing down):
    ; [ESP + 0 ] -> EDI (Start of cpu_state)
    ; [ESP + 32] -> Interrupt Number (pushed by macro)
    ; [ESP + 36] -> Error Code (Start of stack_state)
    
    ; 1. Calculate pointer to 'stack_state' (CS, EIP, EFLAGS, etc.)
    lea eax, [esp + 36]
    push eax        ; Argument 3: stack_state* stack
    
    ; 2. Push Interrupt Number (Value)
    push dword [esp + 32 + 4] ; Argument 2: uint32_t interrupt 
                              ; (+4 because we just pushed 'eax')

    ; 3. Calculate pointer to 'cpu_state' (General Purpose Registers)
    lea eax, [esp + 8]
    push eax        ; Argument 1: cpu_state* cpu

    call interrupt_handler ; Call the C++ function!
    
    add esp, 12     ; Clean up the 3 arguments we just pushed (4 bytes * 3)

    popad           ; Restore the General Purpose Registers (must be reverse of pushad)

    add esp, 8      ; Clean up the stack: remove the Interrupt Number and Error Code 
                    ; (4 bytes + 4 bytes = 8) we pushed in the macros.
    
    iret            ; Interrupt Return: Pops CS, EIP, EFLAGS and resumes execution.

; -----------------------------------------------------------------------------
; Interrupt Service Routines (ISRs) Definitions
; -----------------------------------------------------------------------------

; --- Intel Reserved Exceptions (0-31) ---
isr_no_err 0   ; Divide by Zero
isr_no_err 1   ; Debug
isr_no_err 2   ; NMI
isr_no_err 3   ; Breakpoint
isr_no_err 4   ; Overflow
isr_no_err 5   ; Bound Range Exceeded
isr_no_err 6   ; Invalid Opcode
isr_no_err 7   ; Device Not Available
isr_err    8   ; Double Fault (Has Error Code)
isr_no_err 9   ; Coprocessor Segment Overrun
isr_err    10  ; Invalid TSS (Has Error Code)
isr_err    11  ; Segment Not Present (Has Error Code)
isr_err    12  ; Stack-Segment Fault (Has Error Code)
isr_err    13  ; General Protection Fault (Has Error Code)
isr_err    14  ; Page Fault (Has Error Code)
isr_no_err 15  ; Reserved
isr_no_err 16  ; x87 Floating-Point Exception
isr_err    17  ; Alignment Check
isr_no_err 18  ; Machine Check
isr_no_err 19  ; SIMD Floating-Point Exception
isr_no_err 20  ; Virtualization Exception
isr_no_err 21  ; Reserved
isr_no_err 22  ; Reserved
isr_no_err 23  ; Reserved
isr_no_err 24  ; Reserved
isr_no_err 25  ; Reserved
isr_no_err 26  ; Reserved
isr_no_err 27  ; Reserved
isr_no_err 28  ; Reserved
isr_no_err 29  ; Reserved
isr_err    30  ; Security Exception
isr_no_err 31  ; Reserved

; --- PIC (Hardware) Interrupts (32-47) ---
isr_no_err 32  ; Timer (IRQ0)
isr_no_err 33  ; Keyboard (IRQ1)
isr_no_err 34
isr_no_err 35
isr_no_err 36
isr_no_err 37
isr_no_err 38
isr_no_err 39
isr_no_err 40  ; CMOS Real Time Clock (IRQ8)
isr_no_err 41
isr_no_err 42
isr_no_err 43
isr_no_err 44  ; PS/2 Mouse (IRQ12)
isr_no_err 45
isr_no_err 46
isr_no_err 47

; -----------------------------------------------------------------------------
; load_idt
; Helper to execute the LIDT instruction
; -----------------------------------------------------------------------------
global load_idt
load_idt:
    mov eax, [esp+4] ; Get the pointer argument passed from C++
    lidt [eax]       ; Load Interrupt Descriptor Table Register
    ret

; -----------------------------------------------------------------------------
; isr_table
; A simple array of pointers to the ISR stubs defined above.
; C++ uses this to populate the IDT.
; -----------------------------------------------------------------------------
global isr_table
isr_table:
%assign i 0 
%rep    48 
    dd isr_%+i ; 'dd' = define double word (32-bit pointer)
%assign i i+1 
%endrep