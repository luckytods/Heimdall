package main

import (
	"bufio"
	"fmt"
	"log"
	"net/http"
	"os"
)

func checkStatus(url string) string {
	response, err := http.Get(url)
	if err != nil {
		return err.Error()
	}
	defer response.Body.Close()
	return response.Status
}

func main() {
	var domain string
	fmt.Println("                           _____     ____      ___")
	fmt.Println("        |\\  |\\   |\\   /|  |  _  \\   |  _ \\    / _ \\")
	fmt.Println("        | | | |  | | | |  | | \\  |  | | \\ \\  | | | |")
	fmt.Println("        | |_| |  \\ \\_/ /  | |  | |  | |_/ /  | |_| |")
	fmt.Println("        |  _  |   \\   /   | |  | |  |  _ /   |  _  |")
	fmt.Println("        | | | |    | |    | |  | |  | |\\ \\   | | | |")
	fmt.Println("        | | | |    | |    | |_/  |  | | \\ \\  | | | |")
	fmt.Println("         \\|  \\|    \\ /    |_____/   |/   \\/  |/   \\|")
	fmt.Println("\nVer. 0.0.1")
	fmt.Print("\n\nURL: ")
	fmt.Scan(&domain)

	file, errF := os.Open("namelist.txt")
	if errF != nil {
		log.Fatal(errF)
	}
	defer file.Close()
	scanner := bufio.NewScanner(file)
	response := checkStatus("https://www." + domain)
	fmt.Println(domain + "/" + scanner.Text() + "\t:" + response)
	for scanner.Scan() {
		response := checkStatus("https://www." + domain + "/" + scanner.Text())
		fmt.Println(domain + "/" + scanner.Text() + "\t\t:" + response)
	}

}
