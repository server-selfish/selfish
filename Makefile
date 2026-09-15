cert-gen:
	@mkdir -p ./gateway/cert
	@openssl req -x509 -newkey rsa:4096 -keyout ./gateway/cert/server.key -out ./gateway/cert/server.crt -days 365 -nodes -subj "/C=ID/ST=Jakarta/L=Jakarta/O=YourOrg/OU=IT/CN=localhost"
