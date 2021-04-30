package main

// #include <unistd.h>
// #include <sys/wait.h>
import "C"

import (
	"crypto/aes"
	"crypto/cipher"
	"encoding/base64"
	"io"
	"io/ioutil"
	"log"
	"os"
	"path"
	"path/filepath"
	"strings"
	"syscall"
	"time"
)

var (
	modelFile         = "saved_model.pb"
	encryptedFilePath = "/encrypted/saved_model.pb.encrypted"
)

func main() {
	var modelBaseDir string
	args := os.Args
	for i := 0; i < len(args); i++ {
		if strings.Contains(args[i], "model_base_path=") {
			modelBaseDir = strings.Split(args[i], "=")[1]
			break
		} else if strings.Contains(args[i], "model_base_path") && (i+1 < len(args)) {
			modelBaseDir = args[i+1]
			break
		}
	}

	log.SetPrefix("[Model Decryption] ")

	if len(modelBaseDir) <= 0 {
		log.Fatal("missing required flag [--model_base_path]")
	}

	if os.Getenv("EDG_DECRYPT_MODEL") == "1" {
		key, err := loadKey()
		if err != nil {
			log.Panic(err)
		}

		if key != nil {
			for {
				if err := decryptModel(key, modelBaseDir); err != nil {
					if !os.IsNotExist(err) {
						log.Panic(err)
					}
					// assume the model is present as a decrypted file, since we dont have an encrypted model
					log.Printf("Missing File %v, Trying again in 10 Seconds\n", err)
					time.Sleep(10 * time.Second)
				} else {
					break
				}
			}
		}
	}

	log.Printf("spawning main process %s\n", os.Args[0])
	argv := toCArray(os.Args)
	envp := toCArray(os.Environ())

	// spawn service
	if res := C.execve(C.CString(os.Args[0]), &argv[0], &envp[0]); res != 0 {
		panic(syscall.Errno(res))
	}
	C.wait(nil)
}

func loadKey() ([]byte, error) {
	// load Key
	log.Println("loading decryption key")
	encodedKey, err := ioutil.ReadFile("./model_key")
	if err != nil {
		return nil, err
	}
	return base64.StdEncoding.DecodeString(string(encodedKey))
}

func decryptModel(key []byte, modelBaseDir string) error {
	// prepare ciphertext
	log.Println("starting model decryption")
	encryptedFile, err := os.Open(encryptedFilePath)
	if err != nil {
		return err
	}
	defer encryptedFile.Close()

	block, err := aes.NewCipher(key)
	if err != nil {
		return err
	}

	fileInfo, err := encryptedFile.Stat()
	if err != nil {
		return err
	}

	iv := make([]byte, block.BlockSize())
	msgLen := fileInfo.Size() - int64(len(iv))
	_, err = encryptedFile.ReadAt(iv, msgLen)
	if err != nil {
		return err
	}

	// prepare output file
	if _, err := os.Stat(modelBaseDir); os.IsNotExist(err) {
		os.MkdirAll(filepath.Join(modelBaseDir, "1"), 0744)
	}
	plaintextFile, err := os.OpenFile(path.Join(modelBaseDir, "1", modelFile), os.O_RDWR|os.O_CREATE, 0644)
	if err != nil {
		return err
	}
	defer plaintextFile.Close()

	// decrypt file
	buffer := make([]byte, 512)
	unsealer := cipher.NewCTR(block, iv)
	for {
		n, err := encryptedFile.Read(buffer)
		if n > 0 {
			// make sure to not read the IV as part of the encrypted data
			if n > int(msgLen) {
				n = int(msgLen)
			}
			msgLen -= int64(n)
			unsealer.XORKeyStream(buffer, buffer[:n])

			plaintextFile.Write(buffer[:n])
		}
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
	}

	log.Println("finished decrypting model")
	return nil
}

func toCArray(arr []string) []*C.char {
	result := make([]*C.char, len(arr)+1)
	for i, s := range arr {
		result[i] = C.CString(s)
	}
	return result
}
