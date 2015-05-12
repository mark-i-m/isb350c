mov @data 0 // base of array

mov 1 1     // 1
mov FF 2    // looking for 0x00FF

mov 1  5    // outer loop count
mov 80 6

loop2:
mov 0 3     // i
mov 0 4     // arr[i]

add 5 5 5   // advance outer loop

loop1:
jeq 2 4 4   // if arr[i] = FF: halt
ldr 0 3 4   // reg4 <= arr[i+1]
add 1 3 3   // i++
jmp @loop1  // loop

end:
jeq 5 6 2
jmp @loop2
halt

data:
CAFE
BABE
ACED
DEAD
BEAD
DEED
FACE
FADE
BADE
FEED
DEAF
DADA
BABA
BACE
00FF
