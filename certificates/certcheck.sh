#!/bin/bash

# Certificate checker
# Check if the modulus of a public PEM certificate and a private key match.
# J.R. Lambea 20201002

if [[ $# != 2 ]]; then
    echo "Usage:"
    echo "    $0 public.crt private.key"
    exit 5
fi

Public=$1
Private=$2

if [ ! -s $Public ] || [ ! -s $Private ]; then
    echo "ERROR: Files $1 and $0 must exist."
    exit 6
fi

PubMod="$(openssl x509 -modulus -noout -in ${Public} | openssl md5)"
PrivMod="$(openssl rsa -modulus -noout -in ${Private} | openssl md5)"

if [ -z "$PubMod" ] || [ -z "$PrivMod" ]; then
    echo "ERROR: The files cannot be processed."
    exit 7
fi

if [[ $PubMod == $PrivMod ]]; then
    echo -e "The certificate and the key \e[32mMATCH\e[39m."
else
    echo -e "The certificate and the key \e[31mNOT MATCH\e[39m."
    exit 1
fi
