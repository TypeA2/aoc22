    .global _start
    .text
_start:
    # Stack layout:
    # argv[n] ...
    # argv[1]
    # argv[0]
    # argc

    # Confirm we have 1 argument
    cmpl $2, (%rsp)
    je can_start

    # Nope, exit
    movq $argstr, %rdi
    call puts

    movl $1, %edi
    call exit
can_start:
    # Open source file
    movq 16(%rsp), %rdi
    call open_read

    cmpl $0, %eax
    jns cont0

    movq $openstr, %rdi
    call puts

    movl $1, %edi
    call exit
cont0:
    # Reserve 16 bytes of stack for now
    pushq %rbp
    movq %rsp, %rbp
    subq $32, %rsp

    # Store fd at -4
    movl %eax, -4(%rbp)

    movl -4(%rbp), %edi
    call filesize

    # Exit if file is empty
    testq %rax, %rax
    jnz file_not_empty

    movl -4(%rbp), %edi
    call close

    movl $1, %edi
    call exit

file_not_empty:
    # Filesize at -16
    movq %rax, -16(%rbp)

    xorq %rdi, %rdi # addr
    movq -16(%rbp), %rsi # filesize
    movq $1, %rdx # PROT_READ
    movq $2, %r10 # MAP_PRIVATE
    movq -4(%rbp), %r8 # fd
    xorq %r9, %r9 # offset
    movl $9, %eax # mmap
    syscall

    # Mapped addr at -24
    movq %rax, -24(%rbp)

    # Close input file, mmap keeps it open
    movl -4(%rbp), %edi
    call close

    # %rax is current position
    # %rbx is file eof
    # %rsi is current score
    movq -24(%rbp), %rax
    movq %rax, %rbx
    addq -16(%rbp), %rbx
    xorq %rsi, %rsi

    jmp play_cmp
play_start:
    # %rcx is enemy move
    # %rdx is our move
    movzbq 0(%rax), %rcx
    movzbq 2(%rax), %rdx

    subq $65, %rcx # ASCII 'A'
    subq $88, %rdx # ASCII 'X'
    # 1 = rock
    # 2 = paper
    # 3 = scissors
    # %rcx+1 %rdx+1 result
    # 1      1      1 + 3 = 4
    # 1      2      2 + 6 = 8
    # 1      3      3 + 0 = 3
    # 2      1      1 + 0 = 1
    # 2      2      2 + 3 = 5
    # 2      3      3 + 6 = 9
    # 3      1      1 + 6 = 7
    # 3      2      2 + 0 = 2
    # 3      3      3 + 3 = 6
    # -----------------------
    #                      45
    # LUT indexed with lut[%rcx][%rdx], padded
    movzbq lut(%rdx, %rcx, 4), %rdi
    addq %rdi, %rsi
    addq $4, %rax
play_cmp:
    cmp %rax, %rbx
    jne play_start

    movq %rsi, %rdi
    call printq

    movb $10, %dil
    call putc

cleanup:
    movq -24(%rbp), %rdi # addr
    movq -16(%rbp), %rsi # len
    movl $11, %eax # munmap
    syscall

    # First argument
    movl %eax, %edi
    call exit

    .data
argstr:
    .asciz "Wrong arguments"
    argstr_len = .-argstr

openstr:
    .asciz "Failed to open input file"
    openstr_len = .-openstr

lut:
    .byte 4 # A X
    .byte 8 # A Y
    .byte 3 # A Z
    .byte 0
    .byte 1 # B X
    .byte 5 # B Y
    .byte 9 # B Z
    .byte 0
    .byte 7 # C X
    .byte 2 # C Y
    .byte 6 # C Z
    .byte 0
