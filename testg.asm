mov 0 0
mov 1 1
mov 10 2

loop:
jeq 0 2 3
add 0 1 0
jmp @loop
halt
