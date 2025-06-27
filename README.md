# scripts
A collection of scripts   
<br>
<br>
<br>

## dumbssl.sh

**Usage:** `docker/shared/dumbssl.sh <command> [options]`

A script to manage SSL certificates for Docker and other services.

**Commands:**
*   `create-ca`: Creates a new Root Certificate Authority (CA).
    *   `--name <name>`: (Required) The Common Name (CN) for the CA.
*   `create-key`: Creates a new private key.
    *   `--out <file>`: (Optional) Output file for the key. Default: `key.pem`.
*   `create-csr`: Creates a Certificate Signing Request (CSR).
    *   `--key <file>`: (Required) Path to the private key.
    *   `--out <file>`: (Required) Output file for the CSR.
    *   `--domains <list>`: (Required) Comma-separated list of domains/IPs.
    *   `--type <type>`: (Required) Extended key usage (`server` or `client`).
*   `sign-csr`: Signs a CSR with a CA.
    *   `--csr <file>`: (Required) Path to the CSR file to sign.
    *   `--ca <file>`: (Required) Path to the CA certificate.
    *   `--ca-key <file>`: (Required) Path to the CA private key.
    *   `--out <file>`: (Required) Output file for the new certificate.
*   `install-docker-certs`: Automatically creates and installs a CA and certs for Docker.
*   `help`: Shows this help message.
  
