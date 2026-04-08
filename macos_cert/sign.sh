#!/bin/sh
openssl genrsa -out ALDencryption.key 2048

openssl req -new -key ALDencryption.key -out csr3072ALDEncrypt.certSigningRequest -subj "/emailAddress=montaqa@gmail.com, CN=Maknoon Apps, C=AE"

openssl genrsa -out ALDsigning.key 2048

openssl req -new -key ALDsigning.key -out csr3072ALDSigning.certSigningRequest -subj "/emailAddress=montaqa@gmail.com, CN=Maknoon Apps, C=AE"