package main

// #include <spawn.h>
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
	"syscall"
)

var (
	modelFile = "saved_model.pb"
	modelName = "resnet50-v15-fp32"
	modelBaseDir = "/models"
	encryptedFilePath = "/encrypted/saved_model.pb.encrypted"
)

func main() {
	log.SetPrefix("[Model Decryption] ")

	key, err := loadKey()
	if err != nil {
		if !os.IsNotExist(err) {
			log.Panic(err)
		}
		// assume the model is present as a decrypted file, since we dont have a key
		log.Println("no key found, Skipping model decryption")
	}

	if key != nil {
		if err := decryptModel(key); err != nil {
			if !os.IsNotExist(err) {
				log.Panic(err)
			}
			// assume the model is present as a decrypted file, since we dont have an encrypted model
			log.Printf("error during decryption: %v, skipping decryption\n", err)
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

func decryptModel(key []byte) error {
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
	if _, err := os.Stat(filepath.Join(modelBaseDir, modelName)); os.IsNotExist(err) {
		os.MkdirAll(filepath.Join(modelBaseDir, modelName, "1"), 0744)
	}
	plaintextFile, err := os.OpenFile(path.Join(modelBaseDir, modelName, "1", modelFile), os.O_RDWR|os.O_CREATE, 0644)
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
