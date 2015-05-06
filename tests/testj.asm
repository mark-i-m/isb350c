mov 0 0
mov 1 1
mov 10 2
loop:
jeq 0 2 8
ld 0 A
ld 1 B
ld 2 C
ld 3 D
ld 4 E
add 0 1 0
jmp @loop
halt
