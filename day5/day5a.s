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
    # -32(%rbp) is calculated height
    # -40(%rbp) is calculated width
    # -48(%rbp) points to the start of all moves
    # -56(%rbp) points to the current state table
    # -64(%rbp) is the size of the state table
    # -72(%rbp) is the height of the state table (= width * width + 1)
    # Find first line that starts with a space folowed by a digit
    movq -24(%rbp), %rax
    movq $0, -32(%rbp)
    movq $0, -40(%rbp)
find_height_start:
    # Find first non-space
    movq %rax, %rdi
    call skip_whitespace

    cmpb $91, (%rax) #ASCII '['
    jne find_width

    movq %rax, %rdi
    call skip_line

    incq -32(%rbp)
    jmp find_height_start
find_width:
    # Width is line length plus 1 (skipped whitespace) plus 1 (newline) divided by 4
    pushq %rax
    movq %rax, %rdi
    call linesize
    addq $2, %rax
    shrq $2, %rax
    movq %rax, -40(%rbp)
    movq %rax, %r8

    # Move current position to next line
    popq %rax
    leaq (%rax, %r8, 4), %rax
    movq %rax, -48(%rbp)

    # Allocate width + width * width * height bytes
    movq -40(%rbp), %rax
    mulq -32(%rbp)

    # %rax = width * width
    # Height = width * width + 1
    incq %rax
    movq %rax, -72(%rbp)
    decq %rax

    # Total size = width + width * width * height
    mulq -40(%rbp)
    addq -40(%rbp), %rax

    # Store total size
    movq %rax, -64(%rbp)
    movq %rax, %rdi
    call alloc
    movq %rax, -56(%rbp)

    movq %rax, %rdi
    movb $32, %sil
    movq -64(%rbp), %rdx
    call memset

    # %rax is the current table position
    # %rbx is column height
    # %rcx is current column
    movq -56(%rbp), %rax
    movq -72(%rbp), %rbx
    xorq %rcx, %rcx
set_bottom_start:
    movb $45, -1(%rax, %rbx)

    addq %rbx, %rax
    incq %rcx
set_bottom_cmp:
    cmpq -40(%rbp), %rcx
    jl set_bottom_start

    # Read every column
    # Every row is with * 4 bytes
    # %rax is start of file
    # %rbx is bytes per row
    # %rcx is current column index
    # %rdx is the current position in the state table
    movq -24(%rbp), %rax
    movq -40(%rbp), %rbx
    leaq (,%rbx,4), %rbx
    xorq %rcx, %rcx
    movq -56(%rbp), %rdx
    jmp read_cols_cmp
read_cols_start:
    # Read entire column
    # %rsi is current row
    xorq %rsi, %rsi

    # Add col_height - height to adjust for padding
    addq -72(%rbp), %rdx
    subq -32(%rbp), %rdx
    decq %rdx

    jmp read_row_cmp
read_row_start:
    # %r8 is offset on current row
    leaq 1(,%rcx, 4), %r8

    pushq %rax
    pushq %rdx
    movq %rbx, %rax
    mulq %rsi
    addq %rax, %r8
    popq %rdx
    popq %rax

    # Write next crate to state table
    movb (%rax, %r8), %r8b
    movb %r8b, (%rdx)
    incq %rdx

    incq %rsi
read_row_cmp:
    cmpq -32(%rbp), %rsi
    jl read_row_start

    # Move past end marker
    incq %rdx

    incq %rcx
read_cols_cmp:
    cmpq -40(%rbp), %rcx
    jl read_cols_start

    # State table is in memory, process moves
    # %rax is current position in fie
    # %rbx is eof
    # %rcx points to state table
    movq -48(%rbp), %rax
    movq -24(%rbp), %rbx
    addq -16(%rbp), %rbx
    movq -56(%rbp), %rcx
    jmp moves_cmp
moves_start:
    # Skip "move "
    leaq 5(%rax), %rax

    # %r12 is number of moves
    # %r13 is source
    # %r14 is destination
    pushq %rcx

    movq %rax, %rdi
    call readq
    movq %rax, %r12
    # Skip " from "
    leaq 6(%rdx), %rdi
    call readq
    leaq -1(%rax), %r13

    # Skip " to "
    leaq 4(%rdx), %rdi
    call readq
    leaq -1(%rax), %r14
    leaq 1(%rdx), %rax
    popq %rcx

    # %rdx is how many of the moves have been done
    xorq %rdx, %rdx
    jmp single_move_cmp
single_move_start:
    # %r8b is the byte we're moving
    # %r13 is column we need to read
    # %r9 = %r13 * -72(%rbp) is the start of the column we want
    pushq %rax
    pushq %rdx
    
    movq %r13, %rax
    mulq -72(%rbp)

    # Find the top crate
    leaq (%rcx, %rax), %rdi
    pushq %rcx
    call skip_whitespace
    movb (%rax), %r8b
    movb $32, (%rax)
    
    popq %rcx

    # %r9 = (%r14 * -72(%rbp) is the place we want to insert at
    movq %r14, %rax
    mulq -72(%rbp)
    leaq (%rcx, %rax), %rdi
    pushq %rcx
    call skip_whitespace
    movb %r8b, -1(%rax)

    popq %rcx
    popq %rdx
    popq %rax

    incq %rdx
single_move_cmp:
    cmpq %r12, %rdx
    jl single_move_start

moves_cmp:
    cmpq %rbx, %rax
    jl moves_start

    # Print crates
    # %rax is current column
    # %rbx is current row
    xorq %rbx, %rbx
print_rows_start:
    xorq %rax, %rax
    jmp print_cols_cmp
print_cols_start:
    movq -56(%rbp), %rcx
    # -32(%rbp) * col + row
    pushq %rax
    mulq -72(%rbp)
    addq %rbx, %rax
    movb (%rcx, %rax), %dil

    call putc
    popq %rax
    incq %rax
print_cols_cmp:
    cmpq -40(%rbp), %rax
    jl print_cols_start

    movb $10, %dil
    call putc

    incq %rbx
print_rows_cmp:
    cmpq -72(%rbp), %rbx
    jl print_rows_start

    # Print top crates
    # %rax is the current position in the table
    # %rbx is the current column
    movq -56(%rbp), %rax
    xorq %rbx, %rbx
    jmp print_result_cmp
print_result_start:
    pushq %rax

    movq %rax, %rdi
    call skip_whitespace

    movb (%rax), %dil
    cmpb $45, %dil
    je next
    call putc
next:
    popq %rax
    addq -72(%rbp), %rax
    incq %rbx
print_result_cmp:
    cmpq -40(%rbp), %rbx
    jl print_result_start

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
