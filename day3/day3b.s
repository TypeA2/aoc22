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
    # -32(%rbp) is total count
    movq -24(%rbp), %rax
    movq %rax, %rbx
    addq -16(%rbp), %rbx
    xorq %rcx, %rcx
    movq $0, -32(%rbp)
loop_start:
    pushq %rax
    pushq %rcx

    # Set all counts to 0
    leaq -96(%rbp), %rdi
    xorb %sil, %sil
    movq $52, %rdx
    call memset

    #popq %r8
    popq %rcx
    popq %rax

    # %r8 is inner loop's index
    xorq %r8, %r8
    jmp group_cmp
group_start:
    pushq %rax
    pushq %rcx
    pushq %r8

    movq %rax, %rdi
    call linesize
    movq %rax, %r9

    popq %r8
    popq %rcx
    popq %rax

    # %r9 = digits on this line
    # Count everything in current line
    # %r10 = current position on line
    xorq %r10, %r10
    jmp line_cmp
line_start:
    # %r11 = current char
    movzbq (%rax, %r10), %r11
    cmpq $96, %r11
    jl upper
    # This is a lowercase
    subq $58, %r11 # ASCII 'a' (97) - (65 - 26)
upper:
    subq $39, %r11 # ASCII 'A' (65) - 26 (for indexing)

    # If corresponding item equals %r8, set to %r8 + 1 (advance 1)
    movzbq -96(%rbp, %r11), %r13

    cmpq %r13, %r8
    jne line_cont
    leaq 1(%r8), %r12
    movb %r12b, -96(%rbp, %r11)
line_cont:
    incq %r10
line_cmp:
    cmpq %r9, %r10
    jl line_start

    # Move to next line
    leaq 1(%rax, %r9), %rax

    incq %r8

group_cmp:
    cmpq $3, %r8
    jl group_start

    # Group has been processed, find item with n = 3
    # %r8 = index in array
    xorq %r8, %r8
    jmp find_cmp
find_start:
    cmpb $3, -96(%rbp, %r8)
    jne find_cont

    # Add priority to total
    addq %r8, -32(%rbp)
    incq -32(%rbp)

    jmp find_end
find_cont:
    incq %r8
find_cmp:
    cmpq $52, %r8
    jl find_start
find_end:

loop_cmp:
    cmpq %rax, %rbx
    jne loop_start

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
