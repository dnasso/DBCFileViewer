# Code Signing Setup Guide

This guide explains how to set up code signing for DBC Parser releases using GitHub Actions and GitHub Secrets.

## Overview

The GitHub Actions workflow automatically signs:
- **Windows executable** (`.exe`) and installer with Authenticode
- **Flatpak bundle** with GPG signatures

Signing is optional but highly recommended for production releases. It:
- Establishes trust and provenance
- Prevents Windows SmartScreen warnings
- Allows users to verify artifact authenticity

---

## Windows Code Signing (Authenticode)

### Prerequisites
- A code signing certificate (`.pfx` or `.p12` file)
- Certificate password
- Certificate can be from:
  - Commercial CA (DigiCert, Sectigo, etc.) — best for public releases
  - Self-signed certificate — for testing only
  - Organization certificate — for internal distribution

### Step 1: Prepare Your Certificate

If you have a `.pfx` or `.p12` certificate file, convert it to base64:

**On Windows (PowerShell):**
```powershell
# Convert certificate to base64
$certBytes = [System.IO.File]::ReadAllBytes("C:\path\to\your\certificate.pfx")
$certBase64 = [System.Convert]::ToBase64String($certBytes)
$certBase64 | Out-File -FilePath "certificate_base64.txt" -Encoding ASCII
```

**On Linux/macOS:**
```bash
base64 -i certificate.pfx -o certificate_base64.txt
```

### Step 2: Add GitHub Secrets

1. Go to your GitHub repository: `https://github.com/dnasso/DBCFileViewer`
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add the following secrets:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `WINDOWS_CERT_BASE64` | Contents of `certificate_base64.txt` | Base64-encoded certificate |
| `WINDOWS_CERT_PASSWORD` | Your certificate password | Password to unlock the certificate |

### Step 3: Test Signing

Push a commit or manually trigger the workflow:
```bash
git push origin main-deployment
```

Check the "Sign Windows executable" step in the workflow logs to verify signing succeeded.

### Creating a Self-Signed Certificate (Testing Only)

For testing purposes, create a self-signed certificate:

```powershell
# Create self-signed certificate (valid for 2 years)
$cert = New-SelfSignedCertificate `
    -Type CodeSigningCert `
    -Subject "CN=DBC Parser Development, O=Your Organization, C=US" `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -NotAfter (Get-Date).AddYears(2)

# Export to PFX with password
$password = ConvertTo-SecureString -String "YourPassword123" -Force -AsPlainText
$certPath = "C:\Temp\dbc-parser-dev-cert.pfx"
Export-PfxCertificate -Cert $cert -FilePath $certPath -Password $password

Write-Host "Certificate created: $certPath"
Write-Host "Password: YourPassword123"
```

⚠️ **Warning:** Self-signed certificates will NOT prevent SmartScreen warnings. Use only for internal testing.

---

## Flatpak GPG Signing

### Prerequisites
- GPG keypair (public + private key)
- GPG key should be associated with your email/identity

### Step 1: Generate or Export GPG Key

**Generate a new GPG key (if needed):**
```bash
# Generate GPG key (choose defaults, set real name and email)
gpg --full-generate-key

# List keys to find your Key ID
gpg --list-secret-keys --keyid-format=long
```

**Export existing GPG private key:**
```bash
# Replace YOUR_KEY_ID with your GPG key ID (e.g., ABCD1234)
gpg --export-secret-keys --armor YOUR_KEY_ID > gpg-private-key.asc
```

### Step 2: Add GitHub Secrets

Add the following secrets to your repository:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `GPG_PRIVATE_KEY` | Contents of `gpg-private-key.asc` | Your GPG private key (ASCII armored) |
| `GPG_KEY_ID` | Your GPG Key ID | e.g., `ABCD1234EFGH5678` |

To find your Key ID:
```bash
gpg --list-secret-keys --keyid-format=long
# Look for "sec   rsa4096/YOUR_KEY_ID"
```

### Step 3: Publish Your GPG Public Key

Users need your public key to verify signatures. Publish it:

**Option 1: Upload to keyserver**
```bash
gpg --keyserver keyserver.ubuntu.com --send-keys YOUR_KEY_ID
```

**Option 2: Include in repository**
```bash
# Export public key
gpg --export --armor YOUR_KEY_ID > GPG_PUBLIC_KEY.asc

# Add to repository
git add GPG_PUBLIC_KEY.asc
git commit -m "Add GPG public key for signature verification"
```

### Step 4: Verify Signing

After the workflow runs, verify the Flatpak signature:

```bash
# Import your public key (users will do this)
gpg --import GPG_PUBLIC_KEY.asc

# Verify the flatpak bundle signature
ostree show --repo=flatpak-repo com.qtdevs.DBCParser
```

---

## Security Best Practices

### Certificate/Key Storage
- ✅ **DO:** Store certificates and keys in GitHub Secrets (encrypted at rest)
- ✅ **DO:** Use strong passwords for certificate protection
- ✅ **DO:** Rotate certificates before expiration
- ❌ **DON'T:** Commit certificates or keys to the repository
- ❌ **DON'T:** Share certificate passwords in plain text

### GitHub Secrets Configuration
- Secrets are encrypted and only exposed to workflows
- Never log or echo secret values in workflow steps
- Use environment scoping for production secrets (optional)

### Certificate Lifecycle
1. **Development:** Use self-signed certificates or dev certificates
2. **Testing:** Use organization test certificates
3. **Production:** Use CA-issued code signing certificates with EV (Extended Validation) for best trust

### Timestamping
The workflow uses RFC 3161 timestamping (`/tr http://timestamp.digicert.com`). This ensures signatures remain valid after certificate expiration.

---

## Verifying Signatures

### Windows Authenticode
Users can verify the signature in Windows:
1. Right-click the `.exe` → **Properties**
2. Go to **Digital Signatures** tab
3. Select the signature → **Details**
4. Verify the signer and certificate chain

Or via PowerShell:
```powershell
Get-AuthenticodeSignature .\appDBC_Parser.exe | Format-List
```

### Flatpak GPG
Users can verify GPG signatures:
```bash
# Import your public key
gpg --import GPG_PUBLIC_KEY.asc

# Check repository signatures
flatpak remote-info --show-metadata your-repo com.qtdevs.DBCParser
```

---

## Troubleshooting

### Windows Signing Fails: "SignTool not found"
- Windows SDK must be installed on the runner (GitHub Actions includes it by default)
- Check the workflow logs for the SignTool path detection

### Windows Signing Fails: "Certificate not valid"
- Ensure certificate is not expired
- Verify password is correct
- Check certificate is Code Signing type (not just SSL/TLS)

### GPG Signing Fails: "No secret key"
- Verify `GPG_PRIVATE_KEY` secret contains the full ASCII-armored private key
- Check the key isn't password-protected (or add passphrase handling)
- Ensure `GPG_KEY_ID` matches your actual key ID

### Signature Verification Fails
- For Windows: Certificate must chain to a trusted root CA
- For Flatpak: Users must import your GPG public key first
- Check that timestamping succeeded (allows validation after cert expiration)

---

## Advanced: Hardware Security Modules (HSM)

For production environments, consider using HSM or cloud-based signing:

### Azure Key Vault (Windows)
Replace the certificate decode step with:
```yaml
- name: Sign with Azure Key Vault
  uses: azure/trusted-signing-action@v0.3.0
  with:
    azure-tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    azure-client-id: ${{ secrets.AZURE_CLIENT_ID }}
    azure-client-secret: ${{ secrets.AZURE_CLIENT_SECRET }}
    endpoint: https://xxx.codesigning.azure.net/
    code-signing-account-name: your-account
    certificate-profile-name: your-profile
    files-folder: build-release
    files-to-sign: appDBC_Parser.exe
```

### Sigstore/Cosign (Cross-platform)
For transparency logs and keyless signing:
```yaml
- name: Sign with Sigstore
  uses: sigstore/gh-action-sigstore-python@v2.1.0
  with:
    inputs: flatpak/dbc-parser.flatpak
```

---

## Summary Checklist

- [ ] Generate or obtain code signing certificate (Windows)
- [ ] Convert certificate to base64 and add to GitHub Secrets
- [ ] Generate or export GPG key (Flatpak)
- [ ] Add GPG private key and Key ID to GitHub Secrets
- [ ] Publish GPG public key for users
- [ ] Test workflow by pushing a commit
- [ ] Verify signatures on downloaded artifacts
- [ ] Document verification steps for end users

---

## Questions?

- Windows Code Signing: https://learn.microsoft.com/en-us/windows/win32/seccrypto/cryptography-tools
- GPG Documentation: https://www.gnupg.org/documentation/
- Flatpak Signing: https://docs.flatpak.org/en/latest/reference-flatpakrepo.html

Happy signing! 🔒
