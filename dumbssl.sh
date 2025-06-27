#!/bin/bash


help() {
  echo "Usage: $0 <command> [options]"
  echo ""
  echo "A script to manage SSL certificates for Docker and other services."
  echo ""
  echo "Commands:"
  echo "  create-ca                Creates a new Root Certificate Authority (CA)."
  echo "    --name <name>            (Required) The Common Name (CN) for the CA."
  echo ""
  echo "  create-key               Creates a new private key."
  echo "    --out <file>             (Optional) Output file for the key. Default: key.pem"
  echo ""
  echo "  create-csr               Creates a Certificate Signing Request (CSR)."
  echo "    --key <file>             (Required) Path to the private key."
  echo "    --out <file>             (Required) Output file for the CSR."
  echo "    --domains <list>         (Required) Comma-separated list of domains/IPs."
  echo "    --type <type>            (Required) Extended key usage. One of (server, client)"
  echo ""
  echo "  sign-csr                 Signs a CSR with a CA."
  echo "    --csr <file>             (Required) Path to the CSR file to sign."
  echo "    --ca <file>              (Required) Path to the CA certificate."
  echo "    --ca-key <file>          (Required) Path to the CA private key."
  echo "    --out <file>             (Required) Output file for the new certificate."
  echo ""
  echo "  install-docker-certs     A command to automatically create a CA, server certs,"
  echo "                           and client certs, and install them for Docker."
  echo ""
  echo "  help                     Shows this help message."
}

main() {
  if [[ $# -eq 0 ]]; then
    help
    exit 1
  fi

  local main_command="$1"
  shift

  case "$main_command" in
    create-ca)
      local name
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --name) name="$2"; shift 2;;
          *) echo "Unknown option: $1"; help; exit 1;;
        esac
      done
      if [[ -z "$name" ]]; then echo "Error: --name is required for create-ca"; help; exit 1; fi
      create_rootca "$name"
      ;;
    create-key)
      local out="key.pem"
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --out) out="$2"; shift 2;;
          *) echo "Unknown option: $1"; help; exit 1;;
        esac
      done
      create_sslprivatekey "$out"
      ;;
    create-csr)
      local key out domains type
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --key) key="$2"; shift 2;;
          --out) out="$2"; shift 2;;
          --domains) domains="$2"; shift 2;;
          --type)
            if [[ "$2" == "server" ]]; then
              type="serverAuth"
            elif [[ "$2" == "client" ]]; then
              type="clientAuth"
            else
              echo "Unknown option: $2"
              help
              exit 1
            fi;
            shift 2
            ;;
          *) echo "Unknown option: $1"; help; exit 1;;
        esac
      done
      if [[ -z "$key" || -z "$out" || -z "$domains" || -z "$type" ]]; then echo "Error: --key, --out, and --domains are required."; help; exit 1; fi
      create_cert_signing_request "$key" "$out" "$domains" "$type"
      ;;
    sign-csr)
      local csr ca cakey certout
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --csr) csr="$2"; shift 2;;
          --ca) ca="$2"; shift 2;;
          --ca-key) cakey="$2"; shift 2;;
          --out) certout="$2"; shift 2;;
          *) echo "Unknown option: $1"; help; exit 1;;
        esac
      done
      if [[ -z "$csr" || -z "$ca" || -z "$cakey" || -z "$certout" ]]; then echo "Error: --csr, --ca, --ca-key, and --out are required."; help; exit 1; fi
      sign_srvcsr "$csr" "$ca" "$cakey" "$certout"
      ;;
    install-docker-certs)
      install_docker_certs
      ;;
    help|--help|-h)
      help
      ;;
    *)
      echo "Error: Unknown command '$main_command'"
      help
      exit 1
      ;;
  esac
}


is_ip() {
  local ip="$1"
  local ipv4_regex="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
  local ipv6_regex='^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$'
  if [[ $ip =~ $ipv4_regex || $ip =~ $ipv6_regex ]]; then
    return 0
  else
    return 1
  fi
}

create_sslprivatekey() {
  local outpath="$1"
  outpath=${outpath:-"key.pem"}
  openssl ecparam -name prime256v1 -genkey -noout -out "${outpath}"
  echo "Created private key ${outpath} ✅"
}


create_cert_signing_request() {
  [[ -f ./openssl.cnf ]] && rm ./openssl.cnf
  if [[ $# -ne 4 ]]; then
    echo -e "wrong number of args\nOrder: key,out,domains(, sep list):\n"
    return 1;
  fi
  local srvkey="$1" srvcsr="$2" csl_domains="$3" auth="$4"
  auth=${auth:-"clientAuth"}
  declare -a domainarr
  IFS=',' read -r -a domainarr <<< "$csl_domains"
  local -i ipc=1 dnsc=1
  cat <<- EOF > openssl.cnf
  [req]
  distinguished_name = req_distinguished_name
  req_extensions = v3_req
  prompt = no

  [req_distinguished_name]
  CN = ${domainarr[0]}

  [v3_req]
  keyUsage = digitalSignature, keyEncipherment, dataEncipherment
  extendedKeyUsage = ${auth}
  subjectAltName = @alt_names
EOF
  arrlen=${#domainarr}
  if [[ arrlen -gt 1 ]]; then
    echo -e "[alt_names]" >> openssl.cnf
  fi
  for domain in "${domainarr[@]}"; do
    if is_ip "$domain"; then
      echo "IP.$ipc = $domain" >> openssl.cnf
      ((ipc++))
    else
      echo "DNS.$dnsc = $domain" >> openssl.cnf
      ((dnsc++))
    fi
  done
  echo "" >> openssl.cnf
  cat openssl.cnf
  openssl req -new \
    -key "${srvkey}" \
    -out "${srvcsr}" \
    -sha256 \
    -config openssl.cnf
  echo "Created CSR ${srvcsr} ✅"
}

sign_csr() {
  if [[ $# -ne 4 ]]; then echo -e "wrong number of args\norder: srvcsr,ca,cakey,certout";return 1 ;fi
  local srvcsr="$1" ca="$2" cakey="$3" certout="$4"
  openssl x509 -req -sha256 -days 365 \
    -in "$srvcsr" \
    -CA "$ca" \
    -CAkey "$cakey" \
    -CAcreateserial \
    -out "$certout" \
    -extfile openssl.cnf \
    -extensions v3_req
  rm -f "$srvcsr" openssl.cnf ./*.srl
  echo "Signed ${srvcsr} ✅"
}

create_rootca() {
  local caname="$1"
  cat > ca_openssl.cnf <<-EOF
  [req]
  distinguished_name = req_distinguished_name
  x509_extensions = v3_ca
  prompt = no
  [req_distinguished_name]
  CN = ${caname}
  [v3_ca]
  subjectKeyIdentifier = hash
  authorityKeyIdentifier = keyid:always,issuer
  basicConstraints = critical,CA:true
  keyUsage = critical,digitalSignature,cRLSign,keyCertSign
EOF
  openssl ecparam -name prime256v1 -genkey -noout -out "ca-key.pem"
  openssl req -new -x509 -sha256 -days 730 \
      -key "ca-key.pem" \
      -nodes \
      -out "ca.pem" \
      -config ca_openssl.cnf
  rm ca_openssl.cnf
  echo "Created Docker CA ✅"
}


install_docker_certs() {
  local srvkey="server-key.pem" srvcsr="server.csr" ca="ca.pem" \
    cakey="ca-key.pem" srvcrt="server-cert.pem" clikey="key.pem" \
    clicsr="cli.csr" clicrt="cert.pem" dockdir="$HOME/.docker"

  # Create docker ca
  create_rootca 'Docker CA'

  # Copy to project dir if PROJECT_DIR is set
  if [[ -n $PROJECT_DIR ]]; then
    CADIR="$PROJECT_DIR/.certs/ssl/docker-ca"
    [[ ! -d $CADIR ]] && mkdir -p "$CADIR" && chmod 700 "$CADIR"
    echo "Copying Docker CA to project dir"
    cp "$ca" "$CADIR/$ca"
    cp "$cakey" "$CADIR/$cakey"
    chmod 600 "$CADIR/$ca"
    chmod 600 "$CADIR/$cakey"
  fi

  # Create Server key
  create_sslprivatekey "$srvkey"
  # Create Server Csr
  create_cert_signing_request "$srvkey" "$srvcsr" "localhost,127.0.0.1" "serverAuth"
  # Sign Server Csr
  sign_csr "$srvcsr" "$ca" "$cakey" "$srvcrt"

  USER=${USER:-"$(whoami)"}

  # Create client key
  create_sslprivatekey "$clikey"
  # Create client srvcsr
  create_cert_signing_request "$clikey" "$clicsr" "$USER" "clientAuth"
  # Sign client srvcsr
  sign_csr "$clicsr" "$ca" "$cakey" "$clicrt"

  [[ ! -d $dockdir ]] && mkdir "$dockdir" && chmod 750 "$dockdir"

  echo "Moving Server certs...."
  mv "$srvcrt" "/etc/docker/tls/$srvcrt"
  mv "$srvkey" "/etc/docker/tls/$srvkey"
  cp "$ca" "/etc/docker/tls/$ca"

  echo "Moving client certs...."
  mv "$clicrt" "$dockdir/$clicrt"
  mv "$clikey" "$dockdir/$clikey"
  cp "$ca" "$dockdir/$ca"

  chown -R "${USER}":"${USER}" "$dockdir"
  chmod 600 "/etc/docker/tls/*"
  chmod 600 "$dockdir/*.pem"


  # Calling function to set daemon.json
  set_docker_daemonjson "/etc/docker/daemon.json"
  [[ -n "$PROJECT_DIR" ]] && rm ca.pem ca-key.pem
  echo "Done Creating Docker certs & keys ✅"
}

set_docker_daemonjson() {
  local daemonfile="$1"
  [[ ! -f "$daemonfile" ]] && echo "{}" > "$daemonfile"

  jq \
    '.hosts = ["tcp://localhost:2376", "fd://"] |
     .tlscacert = "/etc/docker/tls/ca.pem" |
     .tlscert = "/etc/docker/tls/server-cert.pem" |
     .tlskey = "/etc/docker/tls/server-key.pem" |
     .tls = true |
     .tlsverify = true |
     .ipv6 = false |
     ."metrics-addr" = "127.0.0.1:9323" |
     .experimental = true' \
    "$daemonfile" > "${daemonfile}.tmp" && mv "${daemonfile}.tmp" "$daemonfile"
  chmod 600 "$daemonfile"
  echo "Updated ${daemonfile} ✅"
}

main "$@"
