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
    # %rcx is total fully contained items
    # -32(%rbp) and -40(%rbp) are temporary storage
    movq -24(%rbp), %rax
    movq %rax, %rbx
    addq -16(%rbp), %rbx
    xorq %rcx, %rcx
loop_start:
    # %r12 = [0].start
    # %r13 = [0].end
    # %r14 = [1].start
    # %r15 = [1].end

    pushq %rcx

    movq %rax, %rdi
    call readq
    movq %rax, %r12

    # %rdx is first non-digit
    leaq 1(%rdx), %rdi
    call readq
    movq %rax, %r13

    leaq 1(%rdx), %rdi
    call readq
    movq %rax, %r14

    leaq 1(%rdx), %rdi
    call readq
    movq %rax, %r15

    leaq 1(%rdx), %rax

    # 0 contains 1 if:
    # (([0].start >= [1].start) && ([0].start <= [1].end) && (([0].end >= [1].start) && ([0].end <= [1].end))
    # Swap 0 and 1 for the other situation
    # Simpler:
    # contained([0].start, [1]) && contained([0].end, [1])


    pushq %rax

    # Allocate 32 additional bytes for our values
    subq $32, %rsp
    movq %r12, (%rsp)
    movq %r13, 8(%rsp)
    movq %r14, 16(%rsp)
    movq %r15, 24(%rsp)

    movq $0, -32(%rbp)

    movq (%rsp), %rdi
    movq 16(%rsp), %rsi
    movq 24(%rsp), %rdx
    call in_range
    addq %rax, -32(%rbp)

    movq 8(%rsp), %rdi
    movq 16(%rsp), %rsi
    movq 24(%rsp), %rdx
    call in_range
    addq %rax, -32(%rbp)

    #movq $0, -40(%rbp)

    movq 16(%rsp), %rdi
    movq (%rsp), %rsi
    movq 8(%rsp), %rdx
    call in_range
    addq %rax, -32(%rbp)

    movq 24(%rsp), %rdi
    movq 0(%rsp), %rsi
    movq 8(%rsp), %rdx
    call in_range
    addq %rax, -32(%rbp)

    movq -32(%rbp), %rdx
    testq %rdx, %rdx
    jz loop_cont
    movq $1, -32(%rbp)
loop_cont:

    addq $32, %rsp

    popq %rax
    popq %rcx

    addq -32(%rbp), %rcx

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
