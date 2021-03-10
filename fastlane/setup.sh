#!/bin/sh

ENCRYPT_KEY=$1

# Decrypt Matchfile
openssl aes-256-cbc -md sha256 -d -in ./fastlane/Matchfile.aes -out ./fastlane/Matchfile -pass password -k $ENCRYPT_KEY

# Decrypt Appfile
openssl aes-256-cbc -md sha256 -d -in ./fastlane/Appfile.aes -out ./fastlane/Appfile -pass password -k $ENCRYPT_KEY
