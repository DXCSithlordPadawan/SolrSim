# Requesting a Certificate from OpenSSL-based CA for Cockpit

Here are the refactored instructions specifically for an OpenSSL-based Certificate Authority:

## Prerequisites
- Access to the CA server (192.168.0.122) or its administrator
- Root CA certificate from your internal CA
- Knowledge of the CA's certificate signing process

## Step 1: Prepare the Certificate Request

### Generate Private Key and CSR
```bash
# Create a directory for certificate files
mkdir -p ~/certificates
cd ~/certificates

# Generate private key
openssl genrsa -out aip.dxc.com.key 2048

# Create a configuration file for the CSR (optional but recommended)
cat > aip.dxc.com.conf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = aip.dxc.com
O = Your Organization
OU = IT Department
L = Your City
ST = Your State
C = US

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = aip.dxc.com
DNS.2 = 192.168.0.51
IP.1 = 192.168.0.51
EOF

# Generate CSR using the configuration
openssl req -new -key aip.dxc.com.key -out aip.dxc.com.csr -config aip.dxc.com.conf
```

## Step 2: Submit CSR to OpenSSL CA

### Method A: Direct Access to CA Server
If you have access to the CA server:

```bash
# Copy CSR to CA server
scp aip.dxc.com.csr user@192.168.0.122:/tmp/

# SSH to CA server and sign the certificate
ssh user@192.168.0.122

# On CA server - sign the certificate
# Assuming standard OpenSSL CA directory structure
cd /etc/ssl/CA  # or wherever your CA is located

# Sign the certificate (adjust paths as needed)
openssl ca -in /tmp/aip.dxc.com.csr -out /tmp/aip.dxc.com.crt \
  -config openssl.cnf \
  -extensions server_cert \
  -days 365

# Copy the signed certificate back
scp /tmp/aip.dxc.com.crt user@192.168.0.51:~/certificates/
```

### Method B: Through CA Administrator
If you don't have direct access:

```bash
# Send the CSR to your CA administrator
echo "Please sign this CSR for aip.dxc.com:"
cat aip.dxc.com.csr
```

## Step 3: Obtain Root CA Certificate

```bash
# Get the root CA certificate from your CA server
scp user@192.168.0.122:/etc/ssl/CA/cacert.pem ~/certificates/ca-root.crt

# Or if available via HTTP
curl -k http://192.168.0.122/ca-root.crt -o ~/certificates/ca-root.crt
```

## Step 4: Verify the Certificate

```bash
# Verify the certificate against the CA
openssl verify -CAfile ~/certificates/ca-root.crt ~/certificates/aip.dxc.com.crt

# Check certificate details
openssl x509 -in ~/certificates/aip.dxc.com.crt -text -noout
```

## Step 5: Create Certificate Chain

```bash
# Create a certificate chain file (certificate + CA)
cat ~/certificates/aip.dxc.com.crt ~/certificates/ca-root.crt > ~/certificates/aip.dxc.com-chain.crt
```

## Step 6: Install Certificate in Cockpit

```bash
# Stop Cockpit service
sudo systemctl stop cockpit

# Backup existing certificates
sudo cp -r /etc/cockpit/ws-certs.d /etc/cockpit/ws-certs.d.backup

# Copy new certificate and key
sudo cp ~/certificates/aip.dxc.com-chain.crt /etc/cockpit/ws-certs.d/0-self-signed.cert
sudo cp ~/certificates/aip.dxc.com.key /etc/cockpit/ws-certs.d/0-self-signed.key

# Alternative: Use specific naming
# sudo cp ~/certificates/aip.dxc.com-chain.crt /etc/cockpit/ws-certs.d/aip.dxc.com.cert
# sudo cp ~/certificates/aip.dxc.com.key /etc/cockpit/ws-certs.d/aip.dxc.com.key

# Set correct permissions
sudo chown root:cockpit-ws /etc/cockpit/ws-certs.d/0-self-signed.*
sudo chmod 640 /etc/cockpit/ws-certs.d/0-self-signed.key
sudo chmod 644 /etc/cockpit/ws-certs.d/0-self-signed.cert

# Start Cockpit service
sudo systemctl start cockpit
sudo systemctl status cockpit
```

## Step 7: Configure DNS and Test

```bash
# Add DNS entry to your local DNS server or hosts file
echo "192.168.0.51 aip.dxc.com" | sudo tee -a /etc/hosts

# Test the connection
curl -v --cacert ~/certificates/ca-root.crt https://aip.dxc.com:9090
```

## Step 8: Install CA Certificate on Client Machines

For browsers to trust your certificate, install the CA root certificate:

### On Linux clients:
```bash
sudo cp ca-root.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

### On Windows clients:
- Import ca-root.crt into "Trusted Root Certification Authorities"

## Troubleshooting

### Check Cockpit certificate status:
```bash
# View current certificates
sudo ls -la /etc/cockpit/ws-certs.d/

# Check Cockpit logs
sudo journalctl -u cockpit -f

# Test certificate manually
openssl s_client -connect aip.dxc.com:9090 -servername aip.dxc.com
```

### Common issues:
- Ensure the certificate includes Subject Alternative Names (SAN)
- Verify the certificate chain is complete
- Check that Cockpit service restarted successfully
- Confirm DNS resolution for aip.dxc.com

Now you should be able to access Cockpit at `https://aip.dxc.com:9090` with a trusted certificate from your internal CA.