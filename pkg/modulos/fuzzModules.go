package modulos

import (
	"bufio"
	"fmt"
	"net/http"
	"strings"
	"sync"
)

func FuzzTarget(url string) (url1 string, url2 string) {
	for idx := strings.Index(url, "FUZZ"); ; {

		idx2 := idx + 4 //idx2 define o index onde a url começa
		fmt.Println("tamanho de url:", len(url))
		url1 = url[:idx]
		fmt.Println(url)
		url = url[idx2:]
		fmt.Println(url)
		idx := strings.Index(url, "FUZZ")
		if idx == -1 {
			break
		}

	}
	url2 = url
	return

}

func CheckStatus(url string) string {
	response, err := http.Get(url)
	if err != nil {
		return err.Error()
	}
	defer response.Body.Close()
	return response.Status
}

func RunFUZZ(threads int, url string, scanner *bufio.Scanner, wg *sync.WaitGroup) {

	URLpre, URLpos := FuzzTarget(url)
	response := CheckStatus("https://www." + URLpre + URLpos)
	fmt.Println(URLpre + URLpos + "\t:" + response)
	if response == "404 Not Found" {
		return //arrumar isso
	}

	c := make(chan string, threads)
	var Chcounter int

	for Chcounter = 0; Chcounter < threads; Chcounter++ {
		fmt.Println(Chcounter)
		if scanner.Scan() {
			c <- scanner.Text()
		} else {
			break
		}
	}
	Chcounter--
	fmt.Println(Chcounter)
	Tcounter := 0
	for {
		if Chcounter < threads-1 {
			if scanner.Scan() {
				c <- scanner.Text()
				Chcounter++
			} else if Chcounter == 0 {
				break
			}
		}
		if Chcounter > 0 && Tcounter < threads {
			Tcounter++
			go func() {
				var fuzz string
				fuzz = <-c
				Chcounter--
				response = CheckStatus("https://www." + URLpre + fuzz + URLpos)
				if response != "404 Not Found" {
					fmt.Println(URLpre + fuzz + URLpos + "\t\t:" + response)
				}
				Tcounter--
			}()
		}
	}
}
