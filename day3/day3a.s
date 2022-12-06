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
    subq $128, %rsp

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

    # %rax is current position in file
    # %rbx is eof
    # %rcx is total priority of duplicate items
    # -96(%rbp) : -44(%rbp) is reserved for character counts
    movq -24(%rbp), %rax
    movq %rax, %rbx
    addq -16(%rbp), %rbx
    xorq %rcx, %rcx
loop_start:
    pushq %rax
    pushq %rcx
    movq %rax, %rdi
    call linesize
    # %r8 is a scratch register for the linesize
    movq %rax, %r8
    
    # Divide in half, this is the size of each compartment
    shrq $1, %r8
    pushq %r8

    # Set all counts to 0
    leaq -96(%rbp), %rdi
    xorb %sil, %sil
    movq $52, %rdx
    call memset

    popq %r8
    popq %rcx
    popq %rax

    # For every character in the first compartment, set the corresponding character to 1
    # %r9 is current character (temporary)
    # %r10 is current offset (remporary)
    # %r12 is ASCII 'A' (65) - 26
    # %r13 is ASCII 'a' (97)
    xorq %r10, %r10
    jmp process_line_cmp
process_line_start:
    movq $39, %r12
    movq $97, %r13
    movzbq (%rax, %r10), %r9
    cmpq $96, %r9 # ASCII 'a' - 1
    # %r11 is temporary subtrahend, assume correct input
    cmovgq %r13, %r11 # %r9 > 96, so lowercase
    cmovlq %r12, %r11 # %r9 < 96, so uppercase
    subq %r11, %r9  # %r9 is now our index

    # Set character to 1
    movb $1, -96(%rbp, %r9)

    incq %r10

process_line_cmp:
    cmpq %r8, %r10
    jl process_line_start

    # First half is processed
    # Move over %rax
    addq %r8, %rax
    xorq %r10, %r10
    jmp compare_compartments_cmp
compare_compartments_start:
    movq $39, %r12
    movq $97, %r13
    movzbq (%rax, %r10), %r9
    cmpq $96, %r9 # ASCII 'a' - 1
    # %r11 is temporary subtrahend, assume correct input
    cmovgq %r13, %r11 # %r9 > 96, so lowercase
    cmovlq %r12, %r11 # %r9 < 96, so uppercase
    subq %r11, %r9  # %r9 is now our index

    testb $0xFF, -96(%rbp, %r9)
    # If nonzero, this is a duplicate, so add %r9+1 to %rcx
    # If zero, skip
    jz compare_compartments_next
    leaq 1(%rcx, %r9), %rcx

    # Set count to 0 after first instance
    movb $0, -96(%rbp, %r9)
compare_compartments_next:
    incq %r10

compare_compartments_cmp:
    cmpq %r8, %r10
    jl compare_compartments_start

    # Move %rax to next line
    leaq 1(%rax, %r8), %rax

loop_cmp:
    cmpq %rax, %rbx
    jne loop_start

    movq %rcx, %rdi
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
