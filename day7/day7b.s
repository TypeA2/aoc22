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
    callq puts

    movl $1, %edi
    callq exit
can_start:
    # Open source file
    movq 16(%rsp), %rdi
    callq open_read

    cmpl $0, %eax
    jns cont0

    movq $openstr, %rdi
    callq puts

    movl $1, %edi
    callq exit
cont0:
    # Reserve 16 bytes of stack for now
    pushq %rbp
    movq %rsp, %rbp
    subq $128, %rsp

    # Store fd at -4
    movl %eax, -4(%rbp)

    movl -4(%rbp), %edi
    callq filesize

    # Exit if file is empty
    testq %rax, %rax
    jnz file_not_empty

    movl -4(%rbp), %edi
    callq close

    movl $1, %edi
    callq exit

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
    callq close

    # struct Node
    # qword type (0 = dir, 1 = file)
    # Node* parent
    # qword name_size
    # char* name
    # qword children_count (or filesize when type = 1)
    # Node* children
    # sizeof(Node) = 48

    # %r12 = position in file
    # %rbx = eof
    # -32(%rbp) = pointer to root
    # %r13 = pointer to current element
    # %r14 = scratch register
    # %r15 = scratch register
    movq -24(%rbp), %r12
    movq -16(%rbp), %rbx
    addq %r12, %rbx
    movq $0, -32(%rbp)
    xorq %r13, %r13
    xorq %r15, %r15
    jmp process_cmp
process_start:
    cmpl $0x64632024, (%r12) # ASCII "$ cd" interpreted as integer
    jne process_not_cd

    # Skip "$ cd "
    leaq 5(%r12), %r12

    # Check if the following 2 characters are dots
    cmpw $0x2e2e, (%r12) # ASCII ".."
    je process_go_up

    # Name length
    movq %r12, %rdi
    callq linesize
    movq %rax, %r14

    cmpq $1, %r14
    jne process_not_root
    # Name is of length 1, check if it's root
    cmpb $47, (%r12) # ASCII '/'
    jne process_not_root
process_is_root:
    # This the root directory, allocate a node
    xorq %rdi, %rdi
    callq node_alloc

    movq %rax, %rdi
    movq %r14, %rsi
    movq %r12, %rdx
    callq node_set_name

    # Store the root and set as current
    movq %rax, -32(%rbp)
    movq %rax, %r13

    # Move to next line
    leaq 1(%r12, %r14), %r12
    jmp process_cmp

process_go_up:
    # Move past the two dots and newline
    leaq 3(%r12), %r12

    movq %r13, %rdi
    callq node_get_parent
    movq %rax, %r13

    # Don't go up from root
    cmpq $0, %r13
    jne process_cmp
    movq $atroot, %rdi
    movq $atroot_len, %rsi
    call prints
    call exit

process_not_root:
    # Find in parent
    # %r14 = filename length
    # %r12 = filename
    movq %r13, %rdi
    movq %r12, %rsi
    movq %r14, %rdx
    xorq %rcx, %rcx
    callq node_find_child

    cmpq $0, %rax
    jne process_child_found
process_child_not_found:
    movq $notfound, %rdi
    movq $notfound_len, %rsi
    call prints
    call exit

process_child_found:
    # Current node the found child
    movq %rax, %r13

    # Print the directory we just entered
    #movq %r13, %rdi
    #movq $2, %rsi
    #callq node_print

    # Move past name
    leaq 1(%r12, %r14), %r12
    jmp process_cmp

process_not_cd:

    # Don't do anything if the entry is already populated
    cmpq $0, 40(%r13)
    je process_new
    # Skip child count + 1 lines
    xorq %r14, %r14
    jmp process_existing_cmp
process_existing_start:
    movq %r12, %rdi
    callq skip_line
    movq %rax, %r12

    incq %r14
process_existing_cmp:
    cmpq 32(%r13), %r14
    jle process_existing_start
    jmp process_cmp

process_new:
    # Next should be "$ ls", move to first entry
    leaq 5(%r12), %r12
    # %r15 = pointer to first entry
    movq %r12, %r15

    # Count number of lines
    xorq %r14, %r14
    jmp process_count_cmp
process_count_start:
    # Gracefully handle EOF
    cmpq %rbx, %r12
    jge process_count_end

    movq %r12, %rdi
    callq skip_line
    movq %rax, %r12

    incq %r14
process_count_cmp:
    cmpb $36, (%r12) # ASCII '$'
    jne process_count_start

process_count_end:

    # Allocate space for all children
    movq %r13, %rdi
    movq %r14, %rsi
    callq node_set_childcount

    # Go back to first entry
    movq %r15, %r12
    # %r14 now contains the number of entries, add to current node
    movq 40(%r13), %r8

    # Parse all entries
    # %r8 = current array start
    # %r15 = index
    xorq %r15, %r15
    jmp process_ls_cmp
process_ls_start:
    # If it starts with ASCII "dir "
    pushq %r8

    movq %r12, %rdi
    cmpl $0x20726964, (%r12)
    jne process_ls_is_file
    # Add a directory entry

process_ls_is_dir:    
    callq node_read_dir
    jmp process_ls_common
process_ls_is_file:
    callq node_read_file
process_ls_common:

    # New string position on next line
    movq %rdx, %r12

    # Set parent on new node
    movq %rax, %rdi
    movq %r13, %rsi
    callq node_set_parent

    # Insert into parent array
    popq %r8
    movq %rax, (%r8, %r15, 8)
    
process_ls_cont:
    incq %r15
process_ls_cmp:
    cmpq %r14, %r15
    jl process_ls_start
process_ls_end:

    #movq %r13, %rdi
    #xorq %rsi, %rsi
    #callq node_print
    #jmp cleanup

process_cmp:
    cmpq %rbx, %r12
    jl process_start

process_end:

    movq -32(%rbp), %rdi
    callq node_resolve_size

    #movq -32(%rbp), %rdi
    #xorq %rsi, %rsi
    #callq node_print

    movq -32(%rbp), %rdi

    movq $70000000, %r8 # Max space
    subq 48(%rdi), %r8 # Unused space
    movq $30000000, %rsi # Required space
    subq %r8, %rsi # Space we need to free up
    movq %rdi, %rdx
    callq node_find_closest

    movq %rax, %rdi
    xorq %rsi, %rsi
    call node_print

cleanup:
    movq -24(%rbp), %rdi # addr
    movq -16(%rbp), %rsi # len
    movl $11, %eax # munmap
    syscall

    # First argument
    movl %eax, %edi
    callq exit

node_read_file:
    # %rdi = pointer to file string
    # post:
    # %rax = pointer to new node
    # %rdx = pointer to next line
    
    # %r13 = current string position
    # -16(%rbp) = %r13
    # -24(%rbp) = filesize
    # -32(%rbp) = filename length
    pushq %rbp
    movq %rsp, %rbp
    subq $32, %rsp

    # Store registers
    movq %r13, -16(%rbp)

    movq %rdi, %r13

    # Get filesize
    movq %r13, %rdi
    callq readq
    movq %rax, -24(%rbp)

    # Skip trailing space
    leaq 1(%rdx), %r13

    # Get filename length
    movq %r13, %rdi
    callq linesize
    movq %rax, -32(%rbp)

    movq $1, %rdi
    call node_alloc

    # node_set_name returns it
    movq %rax, %rdi
    movq -32(%rbp), %rsi
    movq %r13, %rdx

    # Skip ahead already
    leaq (%r13, %rsi), %r13

    callq node_set_name

    # Set filesize
    movq %rax, %rdi
    movq -24(%rbp), %rsi
    callq node_set_filesize
    # %rax = new node

    # Skip the newline
    leaq 1(%r13), %rdx

    # Restore registers
    movq -16(%rbp), %r13
    leaveq
    retq


node_read_dir:
    # %rdi = pointer to dir entry string
    # post:
    # %rax = pointer to new node
    # %rdx = pointer to next line
    
    # %r13 = current string position

    # 32 stack bytes
    # -16(%rbp) = %r13
    # -24(%rbp) = new node pointer
    # -32(%rbp) = line length
    pushq %rbp
    movq %rsp, %rbp
    subq $32, %rsp

    movq %r13, -16(%rbp)

    # Skip "dir " prefix
    leaq 4(%rdi), %r13

    # Allocate new node
    xorq %rdi, %rdi
    callq node_alloc
    movq %rax, -24(%rbp)

    # Remaining line size equals length of name
    movq %r13, %rdi
    callq linesize
    movq %rax, -32(%rbp)

    movq -24(%rbp), %rdi # Node
    movq -32(%rbp), %rsi # Name length
    movq %r13, %rdx      # Name pointer
    callq node_set_name

    # Restore registers
    movq -24(%rbp), %rax
    movq -32(%rbp), %rdx

    # Skip name + newline
    leaq 1(%r13, %rdx), %rdx

    # Old %r13
    movq -16(%rbp), %r13
    leaveq
    retq

node_set_childcount:
    # %rdi = node
    # %rsi = number of children
    pushq %rdi
    pushq %rsi

    # Allocate the array
    leaq (, %rsi, 8), %rdi
    call alloc

    popq %rsi
    popq %rdi

    # Store allocated array and it's size
    movq %rsi, 32(%rdi)
    movq %rax, 40(%rdi)

    pushq %rdi

    # Zero out the array
    movq %rax, %rdi
    xorb %sil, %sil
    leaq (, %rsi, 8), %rdx
    call memset

    popq %rax
    retq

node_get_parent:
    # %rdi = node
    movq 8(%rdi), %rax
    retq

node_set_parent:
    # %rdi = node
    # %rsi = new parent
    movq %rsi, 8(%rdi)
    movq %rdi, %rax
    retq

node_set_name:
    # %rdi = node pointer
    # %rsi = name size
    # %rdx = name pointer
    movq %rsi, 16(%rdi)
    movq %rdx, 24(%rdi)
    movq %rdi, %rax
    retq

node_set_filesize:
    # %rdi = node
    # %rsi = filesize
    movq %rsi, 48(%rdi)
    movq %rdi, %rax
    retq

node_find_closest:
    # %rdi = node
    # %rsi = target size
    # %rdx = current smallest directory node
    # Post:
    # %rax = new smallest directory node

    # Can't be a file
    cmpq $0, (%rdi)
    je not_file
    movq %rdx, %rax
    retq
not_file:

    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    # %r12 = Current node
    # %r13 = Target size
    # %r14 = Current smallest
    # %r15 = Child index
    movq %rdi, %r12
    movq %rsi, %r13
    movq %rdx, %r14
    xorq %r15, %r15
    jmp loop_cmp
loop_start:
    # Get %r15'th child in %rdi
    movq 40(%r12), %rdi
    movq (%rdi, %r15, 8), %rdi

    # If it's smaller than the current smallest yet still large enough to satisfy
    # the request, set this as the new smallest

    # First check if it's smaller than the current smallest
    movq 48(%rdi), %rcx # %rcx = this child's size
    cmpq 48(%r14), %rcx
    jge continue
    # It's smaller, check it's still large enough
    cmpq %r13, %rcx
    jl continue
    # It's large enough to satisfy the request, it's the new smallest
    movq %rdi, %r14

continue:
    # Setup arguments
    movq %r13, %rsi
    movq %r14, %rdx
    callq node_find_closest

    # %rax is the new smallest
    movq %rax, %r14

    incq %r15
loop_cmp:
    cmpq 32(%r12), %r15
    jl loop_start

    movq %r14, %rax
    
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    retq

node_gather_small_dirs:
    # %rdi = node
    # Find all directories with a size <= 100'000, recursively
    # Return total size of these in the subtree
    
    # If this directory is smaller than 100k, start with it's size
    xorq %rax, %rax
    cmpq $100000, 48(%rdi)
    jg cont 
    cmovleq 48(%rdi), %rax
    xorq %rsi, %rsi
    #pushq %rdi
    #pushq %rax
    #call node_print
    #popq %rax
    #popq %rdi
cont:
    # For all subdirectories, get their added sizes
    movq 40(%rdi), %r8 # Current
    movq 32(%rdi), %r9
    leaq (%r8, %r9, 8), %r9 # End
    jmp node_gather_small_dirs_cmp
node_gather_small_dirs_start:
    # Pointer to current element
    movq (%r8), %rdi

    # Only check dirs
    cmpq $0, (%rdi)
    jne node_gather_small_dirs_next

    # Store current count
    pushq %rax
    pushq %r8
    pushq %r9

    call node_gather_small_dirs

    popq %r9
    popq %r8

    # Temporarily store child size in %rcx
    movq %rax, %rcx

    # Restore old size
    popq %rax

    # Add subchild size
    addq %rcx, %rax
node_gather_small_dirs_next:
    leaq 8(%r8), %r8
node_gather_small_dirs_cmp:
    cmpq %r9, %r8
    jl node_gather_small_dirs_start
    retq
    

node_resolve_size:
    # %rdi = node
    # If this is a file, no-op since the filesize is set already
    cmpq $1, (%rdi)
    jne node_resolve_dir
    retq

    # Recursively resolve directories
node_resolve_dir:
    pushq %rbp
    movq %rsp, %rbp
    subq $32, %rsp
    # Allocate 32 bytes on our stack

    # -8(%rbp) = our node
    # -16(%rbp) = our size
    # %r8 = children array position
    # %r9 = children array end position
    movq %rdi, -8(%rbp)
    movq $0, -16(%rbp)
    movq 40(%rdi), %r8 # Child array
    movq 32(%rdi), %r9 # Child count
    leaq (%r8, %r9, 8), %r9 # Past-the-end
    
    jmp node_resolve_size_cmp
node_resolve_size_start:
    # Pointer to child
    movq (%r8), %rdi
    # Resolve child
    pushq %r8
    pushq %r9
    pushq %rdi
    call node_resolve_size
    popq %rdi
    popq %r9
    popq %r8

    movq 48(%rdi), %rax
    addq %rax, -16(%rbp)

    leaq 8(%r8), %r8
node_resolve_size_cmp:
    cmpq %r9, %r8
    jl node_resolve_size_start

    # Store calculated size
    movq -16(%rbp), %rax
    movq -8(%rbp), %rcx
    movq %rax, 48(%rcx)

    leaveq
    retq


node_find_child:
    # %rdi, %rsi, %rdx, %rcx
    # parent, string name, string length, type
    cmpq $1, 0(%rdi)
    jne node_find_child_cont
    # Search within a file, so no
    xorq %rax, %rax
    retq
node_find_child_cont:
    pushq %r12
    pushq %r13

    # %r12 = parent to search in
    # %r13 string to compare to
    movq %rdi, %r12
    movq %rsi, %r13
    # For every child...
    # %r8 = children array
    # %r9 = idx
    movq 40(%r12), %r8
    xorq %r9, %r9
    jmp node_find_child_cmp
node_find_child_start:
    # %r10 = Currently inspected child
    movq (%r8, %r9, 8), %r10
    cmpq 16(%r10), %rdx
    jne node_find_child_next # Name sizes don't match

    # Compare name
    pushq %r8
    pushq %r9
    pushq %rdx
    pushq %rcx
    movq 24(%r10), %rdi
    movq %r13, %rsi
    # %rdx is already in place
    callq memcmp
    popq %rcx
    popq %rdx
    popq %r9
    popq %r8

    # 0 means names are the same
    testq %rax, %rax
    jnz node_find_child_next

    # Same type
    cmpq (%r10), %rcx
    jne node_find_child_next

    # Found it
    movq %r10, %rax
    jmp node_find_end
node_find_child_next:
    xorq %rax, %rax
    incq %r9
node_find_child_cmp:
    cmpq 32(%r12), %r9
    jl node_find_child_start
node_find_end:

    popq %r13
    popq %r12
    retq

node_print:
    # %rdi, %rsi
    # src, depth
    pushq %r12
    pushq %r13
    pushq %r14

    # Use %r12 and %r13
    movq %rdi, %r12
    movq %rsi, %r13
    # First print %rsi*2 spaces
    xorq %r14, %r14
    jmp node_pad_cmp
node_pad_start:
    movb $32, %dil
    callq putc
    movb $32, %dil
    callq putc

    incq %r14
node_pad_cmp:
    cmpq %r13, %r14
    jl node_pad_start

    # Print "- "
    movb $45, %dil
    callq putc
    movb $32, %dil
    callq putc

    # Print name
    movq 16(%r12), %rsi # Name size
    movq 24(%r12), %rdi # Name pointer
    callq prints

    cmpq $0, (%r12)
    jne node_print_file
    # Directory

    # Print " (dir)", newline, and all subdirs with depth + 1
    movq $dirstr, %rdi
    movq $dirstr_len, %rsi
    callq prints

    # Child count
    movq 32(%r12), %rdi
    callq printq

    # File size
    movq $dirstr2, %rdi
    movq $dirstr2_len, %rsi
    call prints

    movq 48(%r12), %rdi
    callq printq

    # ")\n"
    movb $41, %dil
    callq putc
    movb $10, %dil
    callq putc

    xorq %r14, %r14
    jmp node_print_children_cmp
node_print_children_start:
    movq 40(%r12), %rdi # Children pointer
    
    # Load pointer to correct child
    movq (%rdi, %r14, 8), %rdi

    # Add 1 to depth
    leaq 1(%r13), %rsi

    callq node_print

    incq %r14
node_print_children_cmp:
    cmpq 32(%r12), %r14
    jl node_print_children_start

    jmp node_print_end

node_print_file:
    # File
    # Print " (file, size="
    movq $filestr, %rdi
    movq $filestr_len, %rsi
    callq prints

    # Print filesize
    movq 48(%r12), %rdi
    callq printq

    # Closing parenthesis and newline
    movb $41, %dil
    callq putc
    movb $10, %dil
    callq putc
node_print_end:
    popq %r14
    popq %r13
    popq %r12
    retq

node_alloc:
    # %rdi = node type
    pushq %rdi
    movq $56, %rdi
    callq alloc

    popq %rdi

    movq %rdi, (%rax) # Type
    movq $0,  8(%rax) # Parent
    movq $0, 16(%rax) # Name size
    movq $0, 24(%rax) # Name
    movq $0, 32(%rax) # Child count
    movq $0, 40(%rax) # Children
    movq $0, 48(%rax) # File size

    # Return address of new Node
    retq

    .data
argstr:
    .asciz "Wrong arguments"
    argstr_len = .-argstr

openstr:
    .asciz "Failed to open input file"
    openstr_len = .-openstr

dirstr:
    .ascii " (dir, children="
    dirstr_len = .-dirstr

dirstr2:
    .ascii ", size="
    dirstr2_len = .-dirstr2

filestr:
    .ascii " (file, size="
    filestr_len = .-filestr

notfound:
    .ascii "child not found\n"
    notfound_len = .-notfound

atroot:
    .ascii "can't go up from root\n"
    atroot_len = .-atroot
