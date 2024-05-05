package uiterminal

import (
	"bufio"
	"fmt"
	"os"
)

func PrintLogo() {
	fmt.Println("                           _____     ____      ___")
	fmt.Println("        |\\  |\\   |\\   /|  |  _  \\   |  _ \\    / _ \\")
	fmt.Println("        | | | |  | | | |  | | \\  |  | | \\ \\  | | | |")
	fmt.Println("        | |_| |  \\ \\_/ /  | |  | |  | |_/ /  | |_| |")
	fmt.Println("        |  _  |   \\   /   | |  | |  |  _ /   |  _  |")
	fmt.Println("        | | | |    | |    | |  | |  | |\\ \\   | | | |")
	fmt.Println("        | | | |    | |    | |_/  |  | | \\ \\  | | | |")
	fmt.Println("         \\|  \\|    \\ /    |_____/   |/   \\/  |/   \\|")
	fmt.Println("\nVer. 0.0.1")
}

func InitMenu() (command string) {

	PrintLogo()
	fmt.Println("---------------------------------------------")
	fmt.Println("-URL {target} : Define the target URL")
	fmt.Println("FUZZ : is the defaut key word for where to fuzz")
	fmt.Println("-wl {path/to/wordlist} : Define the wordlist to use ")
	fmt.Printf("\n\n\n>> ")

	scanner := bufio.NewScanner(os.Stdin)
	scanner.Scan()
	command = scanner.Text()
	return
}
