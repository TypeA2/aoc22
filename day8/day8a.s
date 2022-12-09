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

    # %r12 is the number of visible trees
    # %r13 = y
    # %r14 = x
    # %r15 = start of file
    # %rbx = rowstride minus 2
    movq -24(%rbp), %r15
    movq %r15, %rdi
    callq linesize

    # Prepare to only iterate over inner squares
    leaq -1(%rax), %rbx
    # Add 2 for file's rowstride

    # At least 4 * (dim - 1) trees are visible
    movq %rax, %r12
    decq %r12
    leaq (, %r12, 4), %r12

    # Disregard the outer edges, so:
    # [1, width - 2]
    movq $1, %r13
    jmp loop_y_cmp
loop_y_start:

    movq $1, %r14
    jmp loop_x_cmp
loop_x_start:
    #movq %rbx, %rdi
    leaq 2(%rbx), %rdi
    movq %r14, %rsi
    movq %r13, %rdx
    movq %r15, %rcx
    callq visible
    
    addq %rax, %r12

    #movq %rax, %rdi
    #callq printq
    #movq %rax, %rdi
    #callq printq
    #movq %r14, %rdi
    #call printq
    #movb $32, %dil
    #call putc

    incq %r14
loop_x_cmp:
    cmpq %rbx, %r14 # x < width
    jl loop_x_start

    #movb $10, %dil
    #callq putc

    incq %r13
loop_y_cmp:
    cmpq %rbx, %r13 # y < width
    jl loop_y_start
    

loop_end:

    movq %r12, %rdi
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

get_offset:
    # %rdi = rowstride
    # %rsi = x
    # %rdx = y
    # (rowstride * y) + x
    movq %rdi, %rax
    mulq %rdx
    addq %rsi, %rax
    retq

get_height:
    # %rdi = rowstride incl. newline
    # %rsi = x
    # %rdx = y
    # %rcx = text start
    callq get_offset
    movzbq (%rcx, %rax), %rax
    subq $48, %rax
    retq

visible:
    # %rdi = rowstride
    # %rsi = x
    # %rdx = y
    # %rcx = text pointer
    # returns: bool
    pushq %rbp
    movq %rsp, %rbp
    subq $96, %rsp

    # Store inputs on stack, as backup
    movq %rdi, -8(%rbp)  # Rowstride
    movq %rsi, -16(%rbp) # x
    movq %rdx, -24(%rbp) # y
    movq %rcx, -32(%rbp) # text
    movq %r12, -40(%rbp)
    movq %r13, -48(%rbp)
    movq %r14, -56(%rbp)
    movq %r15, -64(%rbp)
    # -72(%rbp) = current square's height
    # -80(%rbp) = temporary storage
    
    # And in r12-r15
    movq %rdi, %r12 # Rowstride
    movq %rsi, %r13 # x
    movq %rdx, %r14 # y
    movq %rcx, %r15 # text ptr

    # Get current square's height
    # Args are still in place
    # movq %r12, %rdi
    # movq %r13, %rsi
    # movq %r14, %rdx
    # movq %r15, %rcx
    call get_height
    movq %rax, -72(%rbp)

    # %r8 = current x
    # This function never gets called for the edges, so x+1, x-1, y+1 and y-1 are always still valid
    leaq -1(%r14), %r8 # Start above
    jmp up_cmp
up_start:
    movq %r8, -80(%rbp)

    movq %r12, %rdi
    movq %r13, %rsi
    movq %r8, %rdx
    movq %r15, %rcx
    callq get_height

    # If the square is of equal height or higher, this direction is blocked
    cmpq -72(%rbp), %rax
    jge up_blocked
    # View is blocked

    movq -80(%rbp), %r8
    decq %r8
up_cmp:
    cmpq $0, %r8
    jge up_start

    # If we got here the view wasn't blocked in this direction, so return true
    movq $1, %rax
    jmp visible_end
up_blocked:

    # Downwards
    leaq 1(%r14), %r8
    jmp down_cmp
down_start:
    movq %r8, -80(%rbp)

    movq %r12, %rdi
    movq %r13, %rsi
    movq %r8, %rdx
    movq %r15, %rcx
    callq get_height

    cmpq -72(%rbp), %rax
    jge down_blocked

    movq -80(%rbp), %r8
    incq %r8
down_cmp:
    cmpq %r12, %r8
    jl down_start

    # Not blocked downwards
    movq $1, %rax
    jmp visible_end
down_blocked:

    # Left
    leaq -1(%r13), %r8
    jmp left_cmp
left_start:
    movq %r8, -80(%rbp)
    
    movq %r12, %rdi
    movq %r8, %rsi
    movq %r14, %rdx
    movq %r15, %rcx
    callq get_height

    cmpq -72(%rbp), %rax
    jge left_blocked

    movq -80(%rbp), %r8
    decq %r8
left_cmp:
    cmpq $0, %r8
    jge left_start

    movq $1, %rax
    jmp visible_end
left_blocked:

     # Right
     leaq 1(%r13), %r8
     jmp right_cmp
right_start:
    movq %r8, -80(%rbp)
    
    movq %r12, %rdi
    movq %r8, %rsi
    movq %r14, %rdx
    movq %r15, %rcx
    callq get_height

    cmpq -72(%rbp), %rax
    jge right_blocked

    movq -80(%rbp), %r8
    incq %r8
right_cmp:
    cmpq %r12, %r8
    jl right_start

    movq $1, %rax
    jmp visible_end
right_blocked:
visible_blocked:
    xorq %rax, %rax
visible_end:
    # Restore callee-saved registers
    movq -40(%rbp), %r12
    movq -48(%rbp), %r13
    movq -56(%rbp), %r14
    movq -64(%rbp), %r15

    leaveq
    retq

    .data
argstr:
    .asciz "Wrong arguments"
    argstr_len = .-argstr

openstr:
    .asciz "Failed to open input file"
    openstr_len = .-openstr
