package main

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
)

func main() {}

//export decryptModel
func decryptModel() {
	modelFile := "saved_model.pb"
	modelName := "resnet50-v15-fp32"
	modelBaseDir := "/models"
	encryptedFilePath := "/encrypted/saved_model.pb.encrypted"

	// load Key
	encodedKey, err := ioutil.ReadFile("model_key")
	if err != nil {
		// assume the model is present as a decrypted file, since we dont have a key
		if os.IsNotExist(err) {
			log.Println("No key found, Skipping model decryption")
			return
		}
		log.Panic(err)
	}
	key, err := base64.StdEncoding.DecodeString(string(encodedKey))
	if err != nil {
		log.Panic(err)
	}

	// prepare ciphertext
	encryptedFile, err := os.Open(encryptedFilePath)
	if err != nil {
		// assume the model is present as a decrypted file, since we dont have an encrypted model
		if os.IsNotExist(err) {
			log.Printf("No encrypted model found at %s, skipping decryption\n", encryptedFilePath)
			return
		}
		log.Panic(err)
	}
	defer encryptedFile.Close()

	block, err := aes.NewCipher(key)
	if err != nil {
		log.Panic(err)
	}

	fileInfo, err := encryptedFile.Stat()
	if err != nil {
		log.Panic(err)
	}

	iv := make([]byte, block.BlockSize())
	msgLen := fileInfo.Size() - int64(len(iv))
	_, err = encryptedFile.ReadAt(iv, msgLen)
	if err != nil {
		log.Panic(err)
	}

	// prepare output file
	if _, err := os.Stat(filepath.Join(modelBaseDir, modelName)); os.IsNotExist(err) {
		os.Mkdir(filepath.Join(modelBaseDir, modelName), 0744)
	}
	plaintextFile, err := os.OpenFile(path.Join(modelBaseDir, modelName, modelFile), os.O_RDWR|os.O_CREATE, 0644)
	if err != nil {
		log.Panic(err)
	}

	// decrypt file
	buffer := make([]byte, 1024)
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
			log.Panic(err)
		}
	}

	log.Println("Finished decrypting model")
}
