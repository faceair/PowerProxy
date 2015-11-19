@echo off

set domain=%1
set outputPath=%2
set commonname=%domain%

set country=ZH
set state=Shanghai
set locality=Shanghai
set organization=PowerProxy.com
set organizationalunit=PowerProxy
set email=PowerProxy@PowerProxy
set password=r4ww7j93N4H9udNZ

echo Generating key request for %domain%

openssl genrsa -passout pass:%password% -out %domain%.key 2048

echo Removing passphrase from key
openssl rsa -in %domain%.key -passin pass:%password% -out %domain%.key

echo Creating CSR
openssl req -new -key %domain%.key -out %domain%.csr -passin pass:%password% -subj /C=%country%/ST=%state%/L=%locality%/O=%organization%/OU=%organizationalunit%/CN=%commonname%/emailAddress=%email%

openssl x509 -req -days 3650 -in %domain%.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out %domain%.crt
echo Finished
