# hello-go-atomic

This project should help me to research atomics under the hood.

### Narrative

Question for Golang-developer interview - why atomics faster than mutex.

Found [article](https://stackoverflow.com/questions/47445344/is-there-a-difference-in-go-between-a-counter-using-atomic-operations-and-one-us#:~:text=Atomics%20are%20faster%20in%20the,on%20x86%20architectures%2C%20an%20atomic.)
on SOF.

> There is no difference in behavior. There is a difference in performance.

Atomic and mutex works in same way - lock, modify, release.

Mutex works in kernel level.

Atomic - way to lock inside execution on user level.

Okay. Let's find out how atomic do it.

At first I decide that atomic it's implementation of CAS ([wiki](https://en.wikipedia.org/wiki/Compare-and-swap)) 
and it's implemented in Golang (right inside STDLIB).

Pseudocode of CAS from wikipedia with my notes:

```text
function cas(p: pointer to int, old: int, new: int) is
    if *p ≠ old
        return false
    // what if another CPU modify variable in this moment
    *p ← new // if var was modifier with another CPU - race condition here

    return true
```

Hm. Looks like this kind of problem should be solved in another way.

Okay. Let's try to check how does golang code assembly looks like.

Do simple program:

```go
// main.go
package main

import (
	"sync/atomic"
)

func main() {
	counter := uint32(0)

	for idx := 0; idx < 10; idx++ {
		atomic.AddUint32(&counter, 1)
	}

	_ = counter
}
```

And print assembly code to file:

```shell
GOOS=linux GOARCH=amd64 go build -gcflags '-N -l -S' ./main.go > asm.txt 2>&1
```

Flags **-N -l** should disable compiler optimizations 
(I don't want compiler skip unused var and unused loop. Don't touch me useless code. All code I write - useless).
Flag **-S** should print assembly.

Small part of print that should be interesting:

```text
	0x0030 00048 (./main.go:10)	MOVQ	$0, main.idx+16(SP)
	0x0039 00057 (./main.go:10)	JMP	59
	0x003b 00059 (./main.go:10)	CMPQ	main.idx+16(SP), $10
	0x0041 00065 (./main.go:10)	JLT	69
	0x0043 00067 (./main.go:10)	JMP	92
	0x0045 00069 (./main.go:11)	MOVQ	main.&counter+24(SP), AX
	0x004a 00074 (./main.go:11)	MOVL	$1, CX
	0x004f 00079 (./main.go:11)	LOCK                           // o_________@
	0x0050 00080 (./main.go:11)	XADDL	CX, (AX)               // o_________@
	0x0053 00083 (./main.go:11)	JMP	85
	0x0055 00085 (./main.go:10)	INCQ	main.idx+16(SP)
	0x005a 00090 (./main.go:10)	JMP	59
	0x005c 00092 (./main.go:15)	PCDATA	$1, $-1
```

I see combination of two instruction - **LOCK** and **XADDL**. I guess it is atomic implementation.

I am not big fan of assembly and chewing glass, so I need help from Google again.

[LOCK](https://shell-storm.org/x86doc/LOCK.html) instruction need to be ensure that "processor has exclusive access to any shared memory".
Sounds like **LOCK** is mutex on processor level.

[XADD](https://www.felixcloutier.com/x86/xadd) instruction need to increment variable.
I don't know why need **XADD** and why **ADD** is not okay.

But I don't get it. **LOCK-XADD** is Compare-And-Swap or isn't.

God save smart people - we have an [answer](https://groups.google.com/g/mechanical-sympathy/c/3wh8HHzVfUs/m/nI515sgUAQAJ).

> The key difference between a LOCK XADD and a LOCK CAS is that 
> the LOCK XADD will actually and unconditionally force a visible change to the shared memory state 
> in a way that no other processor can prevent, 
> while the shared memory effect of a LOCK CAS operation is a conditional, 
> and will only occur if the compare shows that the expected value and the memory value are the same. 
> Simple (but by no means all) uses of CAS often perform retry loops in lock-free, but not wait-free, mechanisms.

Okay. 
**LOCK-XADD** - restrict another CPUs touching shared memory and modify variable.
**LOCK-CAS** - will try modify again and again till modification don't meet race condition.

I want to see **LOCK-CAS** description in assembly docs to be sure that it isn't joke.

Don't know, may it is [answer](https://developer.arm.com/documentation/ddi0596/2020-12/Base-Instructions/CAS--CASA--CASAL--CASL--Compare-and-Swap-word-or-doubleword-in-memory-).

There is no **CAS** assembly instruction in this [article](https://erikmcclure.com/blog/assembly-cas-implementation/).
But I see another combination - **LOCK-CMPXCHG**.

I guess the [CMPXCHG](https://www.felixcloutier.com/x86/cmpxchg) instruction is *CAS* implementation.

In this [article](https://habr.com/ru/articles/319036/) author show Java code for JDK7:

```java
public final int incrementAndGet() {
    for (;;) {
        int current = get();
        int next = current + 1;
        if (compareAndSet(current, next))
            return next;
    }
}
public final boolean compareAndSet(int expect, int update) {
    return unsafe.compareAndSwapInt(this, valueOffset, expect, update);
}
```

and said that assembly for **unsafe.compareAndSwapInt** looks like:

```text
lock cmpxchg [esi+0xC], ecx
```

Okay!
Golang use **LOCK-XADD**, another languages/platform could use **LOCK-CAS/CMPXCHG**.

I hope this information is enough for answer on interview.

### Useful links

* [XADD instruction](https://www.felixcloutier.com/x86/xadd)
* [XADD instruction](https://sites.google.com/site/microprocessorsbits/arithmetic-instructions/xadd)
* [XADD and locks](https://stackoverflow.com/questions/30130752/assembly-does-xadd-instruction-need-lock)
* [LOCK-XADD explanation](https://groups.google.com/g/mechanical-sympathy/c/3wh8HHzVfUs/m/nI515sgUAQAJ)
* [CAS, lock cmpxchg, Java](https://habr.com/ru/articles/319036/)
* [CMPXCHG instruction](https://www.felixcloutier.com/x86/cmpxchg)
* [CMPXCHG and locks](https://stackoverflow.com/questions/27837731/is-x86-cmpxchg-atomic-if-so-why-does-it-need-lock)
