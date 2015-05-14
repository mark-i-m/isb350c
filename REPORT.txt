isb350c
=======
I implemented a toy version of the ISB prefetcher for a simple OoO processor.
The processor and prefetcher specs are listed below.

The ISB is a prefetcher designed by Akanksha Jain and Calvin Lin. It is
described in their MICRO13 paper "Linearizing Irregular Memory Accesses for
Improved Correlated Prefetching". I will give a short explaination of the design
here, followed by an explanation of my design choices.

About the ISB
=============

PC localization and Address Correlation
---------------------------------------
The ISB is the first design, according to Jain and Lin, that combines PC
localizataion with address correlation efficiently. The term "PC localization"
means that streams are distinguished from each other based on the PC of the
memory access. "Address correlation" refers to the technique of identifying
temporal streams (as opposed to spatial streams).

Many previous designs that attempted to achieve this combination use the GHB, as
described by Nesbit and Smith, which is a generic off-chip data structure for
tracking memory streams. While, the GHB has proved a useful tool in the
literature, it is inefficient at PC localization, which would require following
a linked list in memory on each trigger address.

Jain and Lin's design keeps relavent metadata on-chip for fast access by
introducing TLB syncing (discussed later).

Structural Addresses
--------------------
The ISB is designed to handle irregular data streams. It works by mapping
temporally correlated addresses in the physical address space to consecutive
addresses in an internal "structural address space". Structural addresses are a
construct of the prefetcher and are not visible to the rest of the core.
Addresses that are temporally correlated in the physical address space are also
spatially correlated in the structural address space. Then, a simple regular
stream prefetcher can act on the structural address space with high accuracy.
The resulting prefetch candidates in the structural address space are translated
back into physical addresses and requested from memory.

TLB Syncing
-----------
Jain and Lin suggest that off-chip and on-chip metadata can be synced during TLB
misses and evictions. The notoriously high latency of the these TLB operations
effectively hides the latency of the metadata accesses. Metadata for the current
memory page is kept on chip for the prefetcher's use. When a TLB eviction
occurs, the prefetcher swaps metadata for the evicted page with metadata for the
incoming page.


Components
----------
The ISB has four main components.

1. Physical->Structural Address Map Cache (PSAMC): This data structure stores
the mapping from physical addresses to structural addresses.

2. Structural->Physical Address Map Cache (PSAMC): This data structure stores
the reverse mapping (back to physical addresses). It is not strictly neccessary,
but it allows fast address translation.

3. Training Unit: This component finds pairs of temporally correlated addresses
based on the PC and maps them to consecutive structural addresses.

4. Steam Predictor: This component is a stream buffer that acts on structural
addresses. Given a trigger address, it produces a prefetch candidate address
which can then be requested from memory.


My implementation
=================
Processor Specs
---------------
* ISA
    - 16-bit words
    - 16 1-word general purpose registers
    - 1-word addressable memory
    - 1-word cache blocks
    - 1-word instructions

  Encoding (bits)    | Instruction   | Result
---------------------|---------------|----------------------------------------------
  `0000iiiiiiiitttt` | `mov i,t`     |  `regs[t] = i; pc += 1;`
  `0001aaaabbbbtttt` | `add a,b,t`   |  `regs[t] = regs[a] + regs[b]; pc += 1;`
  `0010jjjjjjjjjjjj` | `jmp j`       |  `pc = j;`
  `0011000000000000` | `halt`        |  <stop fetching instructions>
  `0100iiiiiiiitttt` | `ld i,t`      |  `regs[t] = mem[i]; pc += 1;`
  `0101aaaabbbbtttt` | `ldr a,b,t`   |  `regs[t] = mem[regs[a]+regs[b]]; pc += 1;`
  `0110aaaabbbbdddd` | `jeq a,b,d`   |  `if (regs[a] == regs[b]) { pc += d } else { pc += 1 }`

* OoO (Tomasulo)
    - 1-wide dispatch/commit
    - 2 Functional Units
        - 1 LD unit (no stores)
        - 1 FXU
    - No ROB
    - No branch predictor
    - No support for interupts or exceptions

* 2-ported memory
    - Fast 1-cycle magic fetch port
    - Slow 100-cycle data port
    - No support for stores

Simplifications
---------------
My processor has many unrealistic simplifications that allowed me to finish the
project in a more timely manner. Nonetheless, I did try to keep the main
components of the original ISB and follow the original algorithms as closely as
possible.

1. No store instruction: this is a bit disatisfying to me, but it greatly
simplifies life since neither the processor nor the memory heirarchy need to
worry about changing memory values.

2. No virtual memory: one implication of this simplification is that there is no
TLB, so TLB syncing was not implemented. This was the only major feature of the
ISB that I did not implement.

3. No off-chip storage: since the test programs are very small, I decided not to
use any off-chip storage at all for the ISB. This is just as well since there is
no TLB syncing.

4. Small structural address space: In Jain and Lin's design, the size of on-chip
storage is not a limitation since data can be written to the off-chip storage.
However, since my design does not have off-chip storage, I limit the structural
address space to 32 addresses. When these addresses are used up, the prefetcher
stops training. I could have used an LRU policy to throw out the LRU stream, but
time was short.

Prefetcher Specs
----------------
* Max steam length: 16 addrs (in concept, though I do not strictly enforce this
  in code)
* PS-AMC size: 32 entries, each 1 mapping
* SP-AMC size: 8 entries, each 4 mappings
* Training unit: 4 entries
* Steam predictor: stream buffer, degree 1, lookahead 1
* Prefetches are triggered by L3 accesses
* The prefetcher trains on the L3 access stream
* Prefetches are stored in a prefetch buffer of 4 words, and inserted into the
  L1 cache when they are found to be useful.

Problems encountered
--------------------
* I had some difficulty deciding how to adapt the ISB design to my very
  simplified processor. In particular, the lack of TLB syncing forced me to
limit my structural address space.

* Memory traffic: My design has only one memory port for use by the LD unit
  (core traffic) and the prefetcher (non-critical traffic). Thus, prefetcher
traffic often caused core traffic to slow down. This is a well-known phenomenon
in real prefetchers, as well, but it is greatly exaggerated in my design.

* Memory latency: I found that even though the prefetcher has very high
  accuracy, its coverage in my implementation is often low since prefetches are
not fullfilled early enough to hide latency. This is partially due to the fact
that my memory heirarchy fetches 1-word blocks for simplicity. I wanted to
implement a more realistic memory system, but time was short. In general, the
prefetcher does not hurt performance, but it often does not help either.

* Test programs: The test programs used in this project are not representative
  of real-world programs at all. They were intended to test the correctness of
the processor. As a result, their memory characteristics are not very
representative of the memory access patterns that the ISB was designed for.

Successes
---------
The prefetcher is highly accurate and usually does not reduce performance. I
wrote tests p and q to show this. They follow "large" (too big to fit in the
caches) data structures in memory. testp iterates over an array, and testq
follows a linked list. Note that the ISB is not a speculative prefetcher; that
is, it does not attempt to reduce cold cache misses. For this reason, tests p
and q must iterate over their data structures at least once to see any benefit.

In my implementation, the LD unit is parametrized. Its first parameter specifies
whether to enable prefetching, and the second specifies whether to output
prefetch activity messages. Both take a value of 0 (disable) or 1 (enable).

```
    ld #(1, 1) ld0( ... );
```
(Line 496 of cpu.v)

Doing this, we can see that tests p and q achieve a massive speed up of about 1
CPI! I believe that this lackluster result is explained by the points listed in
the "Problems" section above. On the other hand, we can also see from the
prefetch messages that most (if not all) of the prefetches are useful.

Lessons Learned
---------------
* Don't use verilog; use something higher level (i.e. there is a language worse
  than C or javascript).
* Comments and pseudocode matter most when the language is awful and the design
  complex.
* Complex designs need to be broken into very modular pieces, and abstractions
  are extremely important.
* Designing a memory heirarchy is a very tricky balancing act. Between cache
  performance, the memory controller, and the prefetcher, it was very hard to
keep from degrading performance. Moreover, I was barely able to improve
performance on tests p and q.
* Deciding how and where the prefetcher interacts with the critical path of data
  flow in the processor is also tricky. The ISB is designed to sit mostly off
the critical path, so my job was easier.

Running
=======

To run all tests
```
$ make test
```

To run a particular test X
```
$ make testX
```

To run test X without checking correctness
```
$ make runX
```
