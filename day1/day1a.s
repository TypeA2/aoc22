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

    # -32(%rbp) is the current maximum value
    # %rax is current position
    # %rbx is eof
    # %rcx is the total number of calories in the current entry
    movq $0, -32(%rbp)
    movq -24(%rbp), %rax
    movq %rax, %rbx
    addq -16(%rbp), %rbx
    xorq %rcx, %rcx
count_start:
    # If next char is not a newline, read integer
    # Else if next char is a newline, the entry is finished
    cmpb $10, (%rax)
    je entry_finished
    # Read integer and add to current count
    #pushq %rax
    pushq %rcx

    movq %rax, %rdi
    call readq

    popq %rcx

    # Add new integer to the current value
    addq %rax, %rcx
    # Set current pointer to end of read data
    movq %rdx, %rax

    jmp count_end
entry_finished:
    cmpq -32(%rbp), %rcx
    jl count_next
    movq %rcx, -32(%rbp)
count_next:
    xorq %rcx, %rcx
count_end:
    incq %rax
    cmpq %rax, %rbx
    jne count_start

    movq -32(%rbp), %rdi
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
