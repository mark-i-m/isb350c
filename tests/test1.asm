zero:
mov @zero 0

firstload:
ld @firstload 1
mov 2 2
ld @firstload 3
mov 4 4
add 1 2 2
jmp @b

a:
jmp @a

b:
mov 1 1
add 1 1 1
add 1 1 1
ldr 1 1 F
mov 1 1
ld @thirdload 4
ldr 1 4 4
ldr 1 4 4
add 4 1 5

thirdload:
mov 1 1
mov 1 2
mov 1 3
mov 0 0
mov 1 1
mov 10 2

loop:
jeq 0 2 3
add 1 0 0
jmp @loop
mov 77 7
halt
