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

    # -32(%rbp) = head x
    # -40(%rbp) = head y
    # -48(%rbp) = tail x
    # -56(%rbp) = tail y
    movq $0, -32(%rbp)
    movq $0, -40(%rbp)
    movq $0, -48(%rbp)
    movq $0, -56(%rbp)

    # %r12 = current position
    # %rbx = eof
    # %r13 = entrypoint of "passed" list
    # %r14 = number of moves
    # %r15 = performed moves
    movq -24(%rbp), %r12
    movq %r12, %rbx
    addq -16(%rbp), %rbx

    movq $24, %rdi
    callq alloc
    movq %rax, %r13
    movq $0, 0(%r13)  # Next
    movq $0, 8(%r13)  # x
    movq $0, 16(%r13) # y

    jmp loop_cmp
loop_start:
    leaq 2(%r12), %rdi
    callq readq
    movq %rax, %r14
    xorq %r15, %r15

    incq %rdx
    pushq %rdx # Next line

    /*movb (%r12), %dil
    callq putc
    movb $32, %dil
    callq putc
    movq %r14, %rdi
    callq printq
    movb $10, %dil
    call putc*/

    cmpb $85, (%r12) # ASCII "U"
    je loop_up

    cmpb $82, (%r12) # ASCII "R"
    je loop_right

    cmpb $68, (%r12) # ASCII "D"
    je loop_down

    cmpb $76, (%r12) # ASCII "L"
    je loop_left

    movq $-42, %rdi
    callq exit

up_start:
    # Load head
    movq -32(%rbp), %rdi # hx
    movq -40(%rbp), %rsi # hy

    # And tail
    movq -48(%rbp), %rdx # tx
    movq -56(%rbp), %rcx # ty

    # Preserve across call
    pushq %rdi
    pushq %rsi

    # Move up
    incq %rsi
    # Store new head position
    movq %rsi, -40(%rbp)

    callq adjacent

    popq %rsi
    popq %rdi

    cmpq $1, %rax
    je up_next # Still adjacent, don't move tail
    # Tail is no longer adjacent to head, move to old head position
    movq %rdi, -48(%rbp)
    movq %rsi, -56(%rbp)

    movq %r13, %rdi # List
    movq -48(%rbp), %rsi
    movq -56(%rbp), %rdx
    callq list_insert_if_new
up_next:
    incq %r15
loop_up:
    cmpq %r14, %r15
    jl up_start
    jmp loop_continue

right_start:
    # Load head
    movq -32(%rbp), %rdi # hx
    movq -40(%rbp), %rsi # hy

    # And tail
    movq -48(%rbp), %rdx # tx
    movq -56(%rbp), %rcx # ty

    # Preserve old head position across call
    pushq %rdi
    pushq %rsi

    # Move right
    incq %rdi
    # Store new head position
    movq %rdi, -32(%rbp)

    callq adjacent

    popq %rsi
    popq %rdi

    cmpq $1, %rax
    je right_next # Still adjacent, don't move tail
    # Tail is no longer adjacent to head, move to old head position
    movq %rdi, -48(%rbp)
    movq %rsi, -56(%rbp)

    movq %r13, %rdi # List
    movq -48(%rbp), %rsi
    movq -56(%rbp), %rdx
    callq list_insert_if_new
right_next:
    incq %r15
loop_right:
    cmpq %r14, %r15
    jl right_start
    jmp loop_continue

down_start:
    # Load head
    movq -32(%rbp), %rdi # hx
    movq -40(%rbp), %rsi # hy

    # And tail
    movq -48(%rbp), %rdx # tx
    movq -56(%rbp), %rcx # ty

    # Preserve old head position across call
    pushq %rdi
    pushq %rsi

    # Move down
    decq %rsi
    # Store new head position
    movq %rsi, -40(%rbp)

    callq adjacent

    popq %rsi
    popq %rdi

    cmpq $1, %rax
    je down_next # Still adjacent, don't move tail
    # Tail is no longer adjacent to head, move to old head position
    movq %rdi, -48(%rbp)
    movq %rsi, -56(%rbp)

    movq %r13, %rdi # List
    movq -48(%rbp), %rsi
    movq -56(%rbp), %rdx
    callq list_insert_if_new
down_next:
    incq %r15
loop_down:
    cmpq %r14, %r15
    jl down_start
    jmp loop_continue

left_start:
    # Load head
    movq -32(%rbp), %rdi # hx
    movq -40(%rbp), %rsi # hy

    # And tail
    movq -48(%rbp), %rdx # tx
    movq -56(%rbp), %rcx # ty

    # Preserve old head position across call
    pushq %rdi
    pushq %rsi

    # Move left
    decq %rdi
    # Store new head position
    movq %rdi, -32(%rbp)

    callq adjacent

    popq %rsi
    popq %rdi

    cmpq $1, %rax
    je left_next # Still adjacent, don't move tail
    # Tail is no longer adjacent to head, move to old head position
    movq %rdi, -48(%rbp)
    movq %rsi, -56(%rbp)

    movq %r13, %rdi # List
    movq -48(%rbp), %rsi
    movq -56(%rbp), %rdx
    callq list_insert_if_new
left_next:
    incq %r15
loop_left:
    cmpq %r14, %r15
    jl left_start
    jmp loop_continue

loop_continue:
    popq %r12
loop_cmp:
    cmpq %rbx, %r12
    jl loop_start
loop_end:

    xorq %rax, %rax
    jmp walk_list_cmp
walk_list_start:
    
    
    pushq %rax
    movb $120, %dil
    callq putc
    movb $61, %dil
    callq putc
    movq 8(%r13), %rdi
    callq printq
    movb $32, %dil
    callq putc
    movb $121, %dil
    callq putc
    movb $61, %dil
    callq putc
    movq 16(%r13), %rdi
    callq printq
    movb $10, %dil
    callq putc
    popq %rax
    

    incq %rax
    movq (%r13), %r13
walk_list_cmp:
    cmpq $0, %r13
    jne walk_list_start

    #movq %rax, %rdi
    #callq printq

    #movb $10, %dil
    #callq putc
    
    # ./day9a | sort | uniq | wc -l

cleanup:
    movq -24(%rbp), %rdi # addr
    movq -16(%rbp), %rsi # len
    movl $11, %eax # munmap
    syscall

    # First argument
    movl %eax, %edi
    callq exit

is_same:
    cmpq %rdi, %rdx # x
    jne not_same
    cmpq %rsi, %rcx # y
    jne not_same
    movq $1, %rax
    retq
not_same:
    xorq %rax, %rax
    retq

adjacent:
    # %rdi = x0
    # %rsi = y0
    # %rdx = x1
    # %rcx = y1
    # Wether the second spoint is in the squares surrounding the first
    # Just check every direction
    pushq %rbp
    movq %rsp, %rbp
    subq $32, %rsp

    xorq %rax, %rax

    # -32(%rbp) = x0
    # -24(%rbp) = y0
    # -16(%rbp) = x1
    # -8(%rbp) = y1
    movq %rdi, -32(%rbp)
    movq %rsi, -24(%rbp)
    movq %rdx, -16(%rbp)
    movq %rcx, -8(%rbp)

    call is_same
    cmpq $1, %rax
    je adjacent_same

    # X - -
    # - 0 -
    # - - -
    movq -32(%rbp), %rdi
    decq %rdi
    movq -24(%rbp), %rsi
    incq %rsi

    movq -16(%rbp), %rdx
    movq -8(%rbp), %rcx
    call is_same
    cmpq $1, %rax
    je adjacent_same

    # - X -
    # - 0 -
    # - - -
    movq -32(%rbp), %rdi
    movq -24(%rbp), %rsi
    incq %rsi

    movq -16(%rbp), %rdx
    movq -8(%rbp), %rcx
    call is_same
    cmpq $1, %rax
    je adjacent_same

    # - - X
    # - 0 -
    # - - -
    movq -32(%rbp), %rdi
    incq %rdi
    movq -24(%rbp), %rsi
    incq %rsi

    movq -16(%rbp), %rdx
    movq -8(%rbp), %rcx
    call is_same
    cmpq $1, %rax
    je adjacent_same

    # - - -
    # - 0 X
    # - - -
    movq -32(%rbp), %rdi
    incq %rdi
    movq -24(%rbp), %rsi

    movq -16(%rbp), %rdx
    movq -8(%rbp), %rcx
    call is_same
    cmpq $1, %rax
    je adjacent_same

    # - - -
    # - 0 -
    # - - X
    movq -32(%rbp), %rdi
    incq %rdi
    movq -24(%rbp), %rsi
    decq %rsi

    movq -16(%rbp), %rdx
    movq -8(%rbp), %rcx
    call is_same
    cmpq $1, %rax
    je adjacent_same

    # - - -
    # - 0 -
    # - X -
    movq -32(%rbp), %rdi
    movq -24(%rbp), %rsi
    decq %rsi

    movq -16(%rbp), %rdx
    movq -8(%rbp), %rcx
    call is_same
    cmpq $1, %rax
    je adjacent_same

    # - - -
    # - 0 -
    # X - -
    movq -32(%rbp), %rdi
    decq %rdi
    movq -24(%rbp), %rsi
    decq %rsi

    movq -16(%rbp), %rdx
    movq -8(%rbp), %rcx
    call is_same
    cmpq $1, %rax
    je adjacent_same

    # - - -
    # X 0 -
    # - - -
    movq -32(%rbp), %rdi
    decq %rdi
    movq -24(%rbp), %rsi

    movq -16(%rbp), %rdx
    movq -8(%rbp), %rcx
    call is_same
    cmpq $1, %rax
    je adjacent_same

adjacent_same:
    leaveq
    retq

list_insert_if_new:
    # %rdi = pointer to linked list
    # %rsi = new x
    # %rdx = new y
    jmp find_last_cmp
find_last_start:
    cmpq 8(%rdi), %rsi # Check if x is equal
    jne find_last_next # If not equal skip ahead

    cmpq 16(%rdi), %rdx  # Check if y is equal
    jne find_last_next # If not equal skip ahead
    # This square was already passed, return
    retq
find_last_next:
    movq (%rdi), %rdi
find_last_cmp:
    cmpq $0, (%rdi)
    jne find_last_start
    # No next block

    # Insert a new block
    pushq %rdi
    pushq %rsi
    pushq %rdx

    movq $24, %rdi
    callq alloc

    popq %rdx
    popq %rsi
    popq %rdi

    # Set the new values
    movq $0, (%rax)
    movq %rsi, 8(%rax)
    movq %rdx, 16(%rax)

    # Link to previous node
    movq %rax, (%rdi)

    /*
    movq %rsi, %rdi
    callq printq
    movb $44, %dil
    callq putc

    popq %rdx
    pushq %rdx

    movq %rdx, %rdi
    callq printq
    movb $10, %dil
    callq putc*/

    retq

    .data
argstr:
    .asciz "Wrong arguments"
    argstr_len = .-argstr

openstr:
    .asciz "Failed to open input file"
    openstr_len = .-openstr
