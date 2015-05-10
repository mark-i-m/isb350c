mov @data 0 // base of array
mov 0 3     // index into array
mov 0 4     // arr[i]

mov 1 1     // 1
mov FF 2    // looking for 0x00FF

loop:
jeq 2 4 4   // if arr[i] = FF: halt
ldr 0 3 4   // reg4 <= arr[i+1]
add 1 3 3   // i++
jmp @loop   // loop

end:
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
00FF
