package main

import (
	"archive/zip"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
	"unsafe"
)

const (
	godotVersion = "4.2.2"
	godotZipURL  = "https://github.com/godotengine/godot/releases/download/4.2.2-stable/Godot_v4.2.2-stable_win64.exe.zip"
	godotExeName = "Godot_v4.2.2-stable_win64.exe"
)

func main() {
	if runtime.GOOS != "windows" {
		showError("This launcher is intended for Windows only.")
		return
	}

	exePath, err := os.Executable()
	if err != nil {
		showError(fmt.Sprintf("Unable to locate launcher executable: %v", err))
		return
	}
	projectRoot := filepath.Dir(exePath)

	if _, err := os.Stat(filepath.Join(projectRoot, "project.godot")); err != nil {
		showError("project.godot was not found next to this launcher. Keep RunPirateRPG.exe in the root of the PirateRPG folder.")
		return
	}

	godotExePath := filepath.Join(projectRoot, "tools", "godot", godotExeName)
	if err := ensureGodot(godotExePath); err != nil {
		showError(fmt.Sprintf("Failed to prepare Godot %s: %v", godotVersion, err))
		return
	}

	cmd := exec.Command(godotExePath, "--path", projectRoot)
	cmd.Dir = projectRoot
	if err := cmd.Start(); err != nil {
		showError(fmt.Sprintf("Failed to start Godot: %v", err))
		return
	}
}

func ensureGodot(godotExePath string) error {
	if _, err := os.Stat(godotExePath); err == nil {
		return nil
	}

	if err := os.MkdirAll(filepath.Dir(godotExePath), 0o755); err != nil {
		return err
	}

	zipPath := filepath.Join(os.TempDir(), "pirate-rpg-godot.zip")
	if err := downloadFile(godotZipURL, zipPath); err != nil {
		return err
	}
	defer os.Remove(zipPath)

	if err := unzipSingleExecutable(zipPath, filepath.Dir(godotExePath), godotExeName); err != nil {
		return err
	}
	return nil
}

func downloadFile(url, destination string) error {
	resp, err := http.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("download request failed with status %s", resp.Status)
	}

	out, err := os.Create(destination)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, resp.Body)
	return err
}

func unzipSingleExecutable(zipPath, destinationDir, exeName string) error {
	reader, err := zip.OpenReader(zipPath)
	if err != nil {
		return err
	}
	defer reader.Close()

	for _, file := range reader.File {
		if !strings.EqualFold(filepath.Base(file.Name), exeName) {
			continue
		}
		src, err := file.Open()
		if err != nil {
			return err
		}
		defer src.Close()

		dstPath := filepath.Join(destinationDir, exeName)
		dst, err := os.Create(dstPath)
		if err != nil {
			return err
		}
		defer dst.Close()

		if _, err := io.Copy(dst, src); err != nil {
			return err
		}
		return nil
	}

	return errors.New("godot executable was not found in the downloaded archive")
}

func showError(message string) {
	user32 := syscall.NewLazyDLL("user32.dll")
	messageBox := user32.NewProc("MessageBoxW")

	text, _ := syscall.UTF16PtrFromString(message)
	title, _ := syscall.UTF16PtrFromString("PirateRPG Launcher")

	messageBox.Call(0,
		uintptr(unsafe.Pointer(text)),
		uintptr(unsafe.Pointer(title)),
		0x00000010,
	)
}
