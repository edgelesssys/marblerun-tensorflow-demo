package main

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"path"
)

func main() {
	var targetFile string
	var keyFile string

	flag.StringVar(&targetFile, "m", "", "Path to the file to encrypt")
	flag.StringVar(&keyFile, "k", "", "Path to the RSA public key to use for encryption")

	flag.Parse()

	key, err := genKey(keyFile)
	if err != nil {
		fmt.Printf("Error generating key: %v\n", err)
		return
	}

	if err := encryptFile(key, targetFile); err != nil {
		fmt.Printf("Error during encryption: %v\n", err)
	}

	return
}

// genKey generates a 32 byte AES key and saves it as ${targetFile}.key
func genKey(keyFile string) ([]byte, error) {
	key := make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		return nil, err
	}

	if err := ioutil.WriteFile(keyFile, []byte(base64.StdEncoding.EncodeToString(key)), 0644); err != nil {
		return nil, err
	}

	return key, nil
}

func encryptFile(key []byte, targetFile string) error {
	plaintextFile, err := os.Open(targetFile)
	if err != nil {
		return fmt.Errorf("error opening targetfile %s: %v", targetFile, err)
	}
	defer plaintextFile.Close()

	block, err := aes.NewCipher(key)
	if err != nil {
		return err
	}
	iv := make([]byte, block.BlockSize())
	if _, err := rand.Read(iv); err != nil {
		return err
	}

	if _, err := os.Stat("encrypted/"); os.IsNotExist(err) {
		os.Mkdir("encrypted/", 0744)
	}

	encryptedFile, err := os.OpenFile(fmt.Sprintf("encrypted/%s.encrypted", path.Base(targetFile)), os.O_RDWR|os.O_CREATE, 0644)
	if err != nil {
		return fmt.Errorf("error opening encryption file: %v", err)
	}
	defer encryptedFile.Close()

	buffer := make([]byte, 512)
	sealer := cipher.NewCTR(block, iv)
	for {
		n, err := plaintextFile.Read(buffer)
		if n > 0 {
			sealer.XORKeyStream(buffer, buffer[:n])
			encryptedFile.Write(buffer[:n])
		}
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
	}
	encryptedFile.Write(iv)

	fmt.Printf("Saved encrypted file to: %s\n", encryptedFile.Name())
	return nil
}
