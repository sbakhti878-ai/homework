[bits 32]
[extern kmain]
global start
start:
    call kmain
    jmp $ ; hangs here after the execution of the kernel.