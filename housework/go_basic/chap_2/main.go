package main

import (
	"fmt"
	"sync"
	"sync/atomic"
)

func main() {
	// // 1.1测试
	// var num MyInt
	// for num < 10 {
	// 	num.increment()
	// }
	// fmt.Println(num)

	// // 1.2测试
	// var nums MySlice
	// nums = MySlice{1, 2, 3, 4, 5}
	// nums.double()
	// fmt.Println(nums)

	// // 2.1
	// go printOdd()
	// go printEven()
	// time.Sleep(1 * time.Second)

	// // 2.2
	// tasks := []Task{
	//    {id: 1, name: func() {
	//       time.Sleep(1500 * time.Millisecond)
	//       fmt.Println("任务 1 完成")
	//    }},
	//    {id: 2, name: func() {
	//       time.Sleep(1000 * time.Millisecond)
	//       fmt.Println("任务 2 完成")
	//    }},
	//    {id: 3, name: func() {
	//       time.Sleep(800 * time.Millisecond)
	//       fmt.Println("任务 3 完成")
	//    }},
	// }
	// var wg sync.WaitGroup
	// for _, task := range tasks {
	//    wg.Add(1)
	//    go func(t Task) {
	//       defer wg.Done()
	//       start := time.Now()
	//       t.name()
	//       duration := time.Since(start)
	//       fmt.Printf("任务 %d 耗时: %v\n", t.id, duration)
	//    }(task)
	// }
	// wg.Wait()
	// fmt.Println("所有任务完成")

	// // 3.1
	// r := Rectangle{width: 5, length: 10}
	// c := Circle{radius: 5}
	// var s Shape = &c
	// fmt.Printf("Rectangle Area: %f\n", r.Area())
	// fmt.Printf("Rectangle Perimeter: %f\n", r.Perimeter())
	// fmt.Printf("Circle Area: %f\n", s.Area())
	// fmt.Printf("Circle Perimeter: %f\n", s.Perimeter())

	// // 3.2
	// employee := Employee{
	//    Person: Person{Name: "David", Age: 30},
	//    EmployeeID: 12345,
	// }
	// employee.PrintInfo()

	// 4.1
	// c := make(chan int)
	// go send(c)
	// go recv(c)
	// time.Sleep(1 * time.Second)

	// 4.2
	// cBuffer := make(chan int, 10)
	// go func(c chan int) {
	//    for i := 0; i < 100; i++ {
	//       c <- i
	//       fmt.Println("send", i)
	//    }
	//    close(c)
	// }(cBuffer)
	// go func(c chan int) {
	//    for i := 0; i < 100; i++ {
	//       time.Sleep(100 * time.Millisecond)
	//       fmt.Println(<-c)
	//    }
	// }(cBuffer)
	// time.Sleep(10 * time.Second)

	// 5.1
	// var counter int = 0
	// var mu sync.Mutex
	// var wg sync.WaitGroup
	// for i := 0; i < 10; i++ {
	//    wg.Add(1)
	//    go func() {
	//       defer wg.Done()
	//       increment1000Safe(&counter, &mu)
	//      }()
	// }
	// wg.Wait()
	// fmt.Println(counter)

	// 5.2
	var counter int64 = 0
	var wg sync.WaitGroup
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			increment1000Atomic(&counter)
		}()
	}
	wg.Wait()
	fmt.Println(counter)
}

// 1.1
type MyInt int

func (num *MyInt) increment() {
	*num++
}

// 1.2
type MySlice []int

func (nums *MySlice) double() {
	for idx := range *nums {
		(*nums)[idx] *= 2
	}
}

// 2.1
func printOdd() {
	for i := 1; i <= 10; i++ {
		if i%2 != 0 {
			fmt.Println(i)
		}
	}
}

func printEven() {
	for i := 1; i <= 10; i++ {
		if i%2 == 0 {
			fmt.Println(i)
		}
	}
}

// 2.2
type Task struct {
	id   int
	name func()
}

// 3.1
type Shape interface {
	Area() float64
	Perimeter() float64
}

type Rectangle struct {
	width  float64
	length float64
}

type Circle struct {
	radius float64
}

func (r *Rectangle) Area() float64 {
	return r.width * r.length
}

func (r *Rectangle) Perimeter() float64 {
	return 2 * (r.width + r.length)
}

func (c *Circle) Area() float64 {
	return 3.14 * c.radius * c.radius
}

func (c *Circle) Perimeter() float64 {
	return 2 * 3.14 * c.radius
}

// 3.2
type Person struct {
	Name string
	Age  int
}

type Employee struct {
	Person
	EmployeeID int
}

func (e Employee) PrintInfo() {
	fmt.Printf("Name: %s, Age: %d, EmployeeID: %d\n", e.Name, e.Age, e.EmployeeID)
}

// 4.1
func send(c chan int) {
	for i := 0; i < 10; i++ {
		c <- i
	}
	close(c)
}

func recv(c chan int) {
	for i := 0; i < 20; i++ {
		x, ok := <-c
		fmt.Println(x, ok)
	}
}

// 4.2 见main函数

// 5.1
func increment1000Safe(count *int, mu *sync.Mutex) {
	for i := 0; i < 1000; i++ {
		mu.Lock()
		*count++
		mu.Unlock()
	}
}

// 5.2
func increment1000Atomic(count *int64) {
	for i := 0; i < 1000; i++ {
		atomic.AddInt64(count, 1)
	}
}
