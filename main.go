package main

import (
	_ "embed"
	"os"
	"os/exec"
	"syscall"
)

//go:embed cross.sh
var crossScript []byte

func main() {
	// Create bash command with -s flag to read from stdin
	cmd := exec.Command("bash", "-s", "--")
	cmd.Args = append(cmd.Args, os.Args[1:]...)

	// Create a pipe to send the script content
	stdin, err := cmd.StdinPipe()
	if err != nil {
		os.Stderr.WriteString("Failed to create stdin pipe: " + err.Error() + "\n")
		os.Exit(1)
	}

	// Connect stdout and stderr
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	// Start the command
	if err := cmd.Start(); err != nil {
		os.Stderr.WriteString("Failed to start bash: " + err.Error() + "\n")
		os.Exit(1)
	}

	// Write the script content to stdin
	if _, err := stdin.Write(crossScript); err != nil {
		os.Stderr.WriteString("Failed to write script: " + err.Error() + "\n")
		os.Exit(1)
	}
	stdin.Close()

	// Wait for the command to finish
	if err := cmd.Wait(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			// Get the exit code from bash
			if status, ok := exitErr.Sys().(syscall.WaitStatus); ok {
				os.Exit(status.ExitStatus())
			}
		}
		os.Stderr.WriteString("Failed to execute script: " + err.Error() + "\n")
		os.Exit(1)
	}
}
