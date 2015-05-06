mov 1 1
mov 0 1
ld 0 3
ld @neg 0
ldr 0 3 2

loop:
jeq 1 3 3
add 1 2 1
jmp @loop

halt

data:
neg:
FFF0 // -16
