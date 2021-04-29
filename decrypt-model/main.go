package main

// #include <spawn.h>
// #include <sys/wait.h>
import "C"

import (
	"crypto/aes"
	"crypto/cipher"
	"encoding/base64"
	"flag"
	"io"
	"io/ioutil"
	"log"
	"os"
	"path"
	"path/filepath"
	"syscall"
	"time"
)

var (
	modelFile         = "saved_model.pb"
	encryptedFilePath = "/encrypted/saved_model.pb.encrypted"
)

func main() {
	var modelBaseDir string
	flag.StringVar(&modelBaseDir, "model_base_dir", "", "absolute path to base directory of the model")
	flag.Parse()

	log.SetPrefix("[Model Decryption] ")

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
				}
			}
		}
	}

	log.Printf("spawning main process %s\n", os.Args[0])
	argv := toCArray(os.Args)
	envp := toCArray(os.Environ())

	// spawn service
	if res := C.posix_spawn(nil, C.CString(os.Args[0]), nil, nil, &argv[0], &envp[0]); res != 0 {
		panic(syscall.Errno(res))
	}
	C.wait(nil)
}

func loadKey() ([]byte, error) {
	// load Key
	log.Println("loading decryption key")
	encodedKey, err := ioutil.ReadFile("model_key")
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
