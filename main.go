package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"strings"
	"sync"

	uiterminal "./pkg/UIterminal"
	mod "./pkg/modulos"
)

func ReadCommand(command string) (url string, wl string) {

	cmd := command

	fmt.Println("\n" + command)

	if idx := strings.Index(cmd, " -URL "); idx != -1 || strings.Index(cmd, "-URL ") == 0 {
		idx++

		idx2 := idx + 5 //idx2 define o index onde a url começa
		for cmd[idx2] == 32 {
			idx2++
		} //busca início da url
		idx3 := idx2 + 1
		for cmd[idx3] != 32 {
			if idx3 == len(cmd)-1 {
				idx3++
				break
			}
			idx3++
		} //busca fim da url
		url = cmd[idx2:idx3]
		cmd = cmd[:idx] + cmd[idx3:]
	}
	fmt.Println("command: " + command)
	fmt.Println("cmd: " + cmd)
	fmt.Println("url: " + url)

	if idx := strings.Index(cmd, " -wl "); idx != -1 || strings.Index(cmd, "-wl ") == 0 {
		idx++

		idx2 := idx + 4 //idx2 define o index onde a wl começa
		for cmd[idx2] == 32 {
			idx2++
		} //busca início da wl
		idx3 := idx2 + 1
		for cmd[idx3] != 32 {
			if idx3 == len(cmd)-1 {
				idx3++
				break
			}
			idx3++
		} //busca fim da wl
		wl = cmd[idx2:idx3]
		cmd = cmd[:idx] + cmd[idx3:]
	}

	fmt.Println("command: " + command)
	fmt.Println("cmd: " + cmd)
	fmt.Println("wl: " + wl)

	return
}

func main() {
	var domain string
	var wg sync.WaitGroup
	var wl string
	var threads = 4

	command := uiterminal.InitMenu()

	domain, wl = ReadCommand(command)

	file, errF := os.Open(wl)
	if errF != nil {
		log.Fatal(errF)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	fmt.Println("-------------------------------------------------------------")
	wg.Add(threads)
	mod.RunFUZZ(threads, domain, scanner, &wg)
	fmt.Println("\n-------------------------------------------------------------")
	fmt.Println("\n\nFim do Processo")

}
