package main

func main() {
	counter := uint32(0)

	for idx := 0; idx < 10; idx++ {
		counter++
	}

	_ = counter
}
