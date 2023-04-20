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
