    .text

    .global prints
    # rdi = ptr
    # rsi = bytes
prints:
    # shift our args over by 1
    movq %rsi, %rdx
    movq %rdi, %rsi

    # 1 = write
    movl $1, %eax

    # 1 = stdout
    movl $1, %edi
    # rsi and rdx already in position
    syscall
    retq

    .global printq
printq:
    # Divide parameter
    xorq %rdx, %rdx # mod
    movq %rdi, %rax # div
    movq $10, %rcx
    divq %rcx

    # if val == 0, val < 10, so print, else recursively call
    testq %rax, %rax
    jz printq_l0
    
    # Store current digit
    pushq %rdx

    movq %rax, %rdi
    call printq

    popq %rdx
printq_l0:
    
    # Convert to ascii
    addq $48, %rdx
    movq %rdx, %rdi
    call putc
    retq

    .global putc
putc:
    pushq %rbp
    movq %rsp, %rbp
    subq $16, %rsp

    movb %dil, (%rsp)
    # Call prints for 1 byte
    movq %rsp, %rdi
    movq $1, %rsi
    call prints

    leaveq
    retq

    .global puts
puts:
    # rdi = null-termianted pointer
    # Store string value
    movq %rdi, %rcx
    call strlen
    movq %rax, %rsi

    movq %rcx, %rdi
    call prints

    # ASCII newline
    movb $10, %dil
    call putc
    retq
    
    .global exit
exit:
    movl $60, %eax
    # arg is already in rdi
    syscall

    .global strlen
strlen:
    # rax = len
    xor %rax, %rax
strlen_l0:
    cmpb $0, (%rdi)
    je strlen_l1
    incq %rax
    incq %rdi
    jmp strlen_l0
strlen_l1:
    retq
    
    .global open_read
open_read:
    # Open a file by it's name, retqurn fd
    movl $2, %eax # open
    # filename is already in %rdi
    xor %rsi, %rsi # O_RDONLY
    xor %rdx, %rdx # Mode
    syscall
    retq

    .global close
close:
    movl $3, %eax
    syscall
    retq

    .global readc
# Read a single character
readc:
    # fd is already in %rdi
    # Store in red zone
    leaq -1(%rsp), %rsi
    movq $1, %rdx
    movl $0, %eax # read
    syscall
    movb -1(%rsp), %al
    retq

    .global filesize
filesize:
    # struct stat is 144 bytes
    # offsetof st_size is 48 bytes
    # sizeof st_size is 8 bytes (quad)
    pushq %rbp
    movq %rsp, %rbp
    subq $144, %rsp
    
    # rdi is already fd
    movq %rsp, %rsi
    movl $5, %eax # fstat
    syscall
    
    movq 48(%rsp), %rax

    leaveq
    retq

    .global get_brk
get_brk:
    xorq %rdi, %rdi
    movl $12, %eax # brk
    syscall
    retq

    .global brk
brk:
    # %rdi is already in place
    movl $12, %eax # brk
    syscall
    retq

    .global alloc
alloc:
    # allocate %rdi bytes, return start of allocated area
    movq %rdi, %rbx # Save request size

    # Retrieve current program break
    call get_brk

    # Calculate new brk
    addq %rax, %rbx
    movq %rbx, %rdi
    call brk
    movq %rbx, %rax
    retq

    .global readq
readq:
    # read an 8-byte unsigned integer from an address, stopping at the first invalid digit
    xorq %rax, %rax
    jmp readq_loop_cmp
readq_loop_start:
    # Add new digit
    movq $10, %rdx
    mulq %rdx
    addq %rcx, %rax
    incq %rdi
readq_loop_cmp:
    # Read next digit
    movzbq (%rdi), %rcx

    # Convert from ASCII to integer
    subq $48, %rcx

    # Continue loop if it's a valid integer, else we're done
    cmpq $10, %rcx
    jb readq_loop_start

    # return end pointer in %rdx
    movq %rdi, %rdx
    ret

    .global linesize
linesize:
    movq %rdi, %rax
    jmp linesize_cmp
linesize_l0:
    incq %rax
linesize_cmp:
    cmpb $10, (%rax)
    jne linesize_l0
    subq %rdi, %rax
    ret

    .global memset
memset:
    # %rdi, %sil, %rdx
    # dest, ch, count
    xorq %rax, %rax
    jmp memset_cmp
memset_l0:
    movb %sil, (%rdi, %rax, 1)
    incq %rax
memset_cmp:
    cmpq %rdx, %rax
    jl memset_l0
    ret
