#!/bin/bash

go mod download
go mod tidy

GOOS=linux GOARCH=amd64 go build -gcflags '-N -l -S' ./cmd/sample1/main.go > asm1.txt 2>&1
GOOS=linux GOARCH=amd64 go build -gcflags '-N -l -S' ./cmd/sample2/main.go > asm2.txt 2>&1
GOOS=linux GOARCH=amd64 go build -gcflags '-N -l -S' ./cmd/sample3/main.go > asm3.txt 2>&1

PROJECT_PATH=$(pwd)

sed -i 's|'${PROJECT_PATH}/'|./|g' asm1.txt
sed -i 's|'${PROJECT_PATH}/'|./|g' asm2.txt
sed -i 's|'${PROJECT_PATH}/'|./|g' asm3.txt

rm -f main
