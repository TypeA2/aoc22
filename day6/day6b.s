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

    # %rax is the position in the file
    # %rbx is eof
    # -64(%rbp) is the start of boolean array
    movq -24(%rbp), %rax

    movq %rax, %rbx
    addq -16(%rbp), %rbx

    jmp loop_cmp
loop_start:
    # Reset array
    pushq %rax
    leaq -64(%rbp), %rdi
    movb $0, %sil
    movq $26, %rdx
    call memset
    popq %rax

    # %rcx is the index relative to the current position
    xorq %rcx, %rcx
    jmp check_cmp
check_start:
    movzbq (%rax, %rcx), %r8

    subq $97, %r8 # ASCII 'a'
    # Check if current position has a 1
    # Current char
    cmpb $1, -64(%rbp, %r8)
    je loop_next

    # Unique character for now, set to 1
    movb $1, -64(%rbp, %r8)

    incq %rcx

check_cmp:
    cmpq $14, %rcx
    jl check_start

    jmp loop_end

loop_next:
    incq %rax
loop_cmp:
    cmpq %rbx, %rax
    jl loop_start
loop_end:

    subq -24(%rbp), %rax
    addq $14, %rax
    movq %rax, %rdi
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

in_range:
    # Return true if %rdi >= %rsi && %rdi <= %rdx
    # Guaranteed to only touch %rax
    cmpq %rsi, %rdi # %rdi >= %rsi
    jl in_range_false
    cmpq %rdx, %rdi # %rdi <= %rdx
    jg in_range_false
    movq $1, %rax
    ret
in_range_false:
    xorq %rax, %rax
    ret

    .data
argstr:
    .asciz "Wrong arguments"
    argstr_len = .-argstr

openstr:
    .asciz "Failed to open input file"
    openstr_len = .-openstr
