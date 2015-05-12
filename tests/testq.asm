// node *head;
// node *n;
// int[4] targets = {AAAA, 1111, 7777, 4444};
// int current_target = 0;
// for (; current_target < 4; current_target++){
//     n = head;
//     while (n) {
//         if (n->val = targets[current_target]) {
//             switch(current_target) {
//                 case 0: reg[F] = n;
//                 case 1: reg[E] = n;
//                 case 2: reg[D] = n;
//                 case 3: reg[C] = n;
//             }
//             break;
//         }
//         n = n->next;
//     }
// }
// halt;

mov 0 0 // zero
mov 1 1 // one
mov 4 3 // four

mov @targets 2 // targets
mov 0 5 // current_target

for:
jeq 5 3 8
mov @head 4 // n = head
ldr 2 5 6   // targets[current_target]

while:
jeq 0 4 6 // while (n)
ldr 0 4 7   // n->val
jeq 6 7 5 // if(n->val == target_current)
ldr 1 4 4   // n = n->next
jmp @while
jmp @end // hack because JEQ only takes 1 digit
jmp @forincr
jmp @movtarget

movtarget:
mov 0 8
jeq 5 8 6 // jmp @mov0
add 1 8 8
jeq 5 8 6 // jmp @mov1
add 1 8 8
jeq 5 8 6 // jmp @mov2
jmp @mov3

mov0:
add 0 4 F
jmp @forincr

mov1:
add 0 4 E
jmp @forincr

mov2:
add 0 4 D
jmp @forincr

mov3:
add 0 4 C
jmp @forincr

forincr:
// current_target++
add 1 5 5
jmp @for

end:
halt

data:

targets:
9999
AAAA
7777
4444

// below is a linked list of the form
// struct node {
//     word data;
//     node* next;
// }

n9:
9999
@n10

head:       // first node in linked list
1111
@n2

n8:
8888
@n9

n2:
2222
@n3

n7:
7777
@n8

n3:
3333
@n4

n6:
6666
@n7

n4:
4444
@n5

n5:
5555
@n6

n10:
AAAA
0000
