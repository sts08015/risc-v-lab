# risc-v-lab
**Extended Version of COSE222 Lab**

I implemented risc-v processor that supports every risc-v instructions except privileged instructions.

Feel free to give feedback via email or github if there are any design flaws.

## Testcases
Below assembly codes are tescases that I made to verify built processor's correctness.

### Testcase1
```
lui x1, 0xfffffffff
sltu x3, x2, x1
```

### Testcase2
```
lw x4, 0(x0)
lw x5, 0(x0)
jal x10, 8
add x6, x4, x5
add x7, x4, x5
lw x5, 40(x0)
jalr x11, x5, 22
add x6, x4, x5
add x8, x4, x5
slt x15, x5, x4
slti x16, x5, 11
lui x1, 0x12345678
auipc x2, 0x04000
lb x20, 44(x0)
lh x21, 44(x0)
lbu x22, 44(x0)
lhu x23, 44(x0)
sb x23, 8(x0)
sh x20, 12(x0)
```

### Testcase3 (tricky testcase when it comes to pipelined method)
```
start: lw x4, 0(x0)
       lw x5, 8(x0)
       lw x6, 16(x0)
T1:    add x7, x5, x4
       sub x8, x5, x4
       and x9, x5, x4
       or x10, x5, x4
       xor x11, x5, x4
       addi x27, x4, 1
       addi x28, x4, -7
       andi x29, x4, 15
       ori x30, x4, 16
       xori x31, x4, 15
       beq x7, x8, T1
       sw x7, 24(x0)
       lw x11, 24(x0)
       bne x7, x11, T1 
T2:    lw x4, 32(x0) 
       lw x5, 40(x0) 
       bgeu  x5, x4, T3
       lw x4, 0(x0)
T3:    sll x4, x4, x6
       srli x4, x4, 4
```

## Useful link
Instruction to Bianry : https://luplab.gitlab.io/rvcodecjs/

Simulation            : https://github.com/mortbopet/Ripes
