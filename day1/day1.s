    .global main
    .text
main:
    mov $60, %rax
    mov $42, %rdi
    syscall
