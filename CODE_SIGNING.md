# Code Signing Guide

Code signing adds digital signatures to your executables to:
- Verify the publisher's identity
- Prevent "Unknown Publisher" warnings
- Protect against tampering
- Enable trust on user systems

## Windows Code Signing (Authenticode)

### Prerequisites

1. **Obtain a Code Signing Certificate**

   Options:
   - **Commercial CA** (recommended for distribution)
     - DigiCert: ~$474/year (EV: ~$599/year)
     - Sectigo/Comodo: ~$179/year
     - GlobalSign: ~$299/year
   
   - **Self-Signed Certificate** (for testing only)
     ```powershell
     # Create self-signed certificate (testing only - will show warnings)
     New-SelfSignedCertificate -Subject "CN=YourCompany" `
         -Type CodeSigningCert `
         -CertStoreLocation Cert:\CurrentUser\My `
         -NotAfter (Get-Date).AddYears(5)
     ```

2. **Install Windows SDK** (for signtool.exe)
   ```powershell
   # Via winget
   winget install Microsoft.WindowsSDK
   
   # Or download from: https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/
   ```

### Signing Your Executable

#### Method 1: Using Certificate File (.pfx)

```powershell
# Set paths
$signtool = "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe"
$cert = "path\to\certificate.pfx"
$password = "your_certificate_password"
$exe = "deploy\windows\appDBC_Parser.exe"
$timestamp = "http://timestamp.digicert.com"

# Sign the executable
& $signtool sign `
    /f $cert `
    /p $password `
    /tr $timestamp `
    /td SHA256 `
    /fd SHA256 `
    /d "DBC Parser" `
    /du "https://github.com/dnasso/DBCFileViewer" `
    $exe

# Verify signature
& $signtool verify /pa $exe
```

#### Method 2: Using Certificate from Store

```powershell
# List certificates
Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert

# Sign using thumbprint
$thumbprint = "YOUR_CERT_THUMBPRINT"
& $signtool sign `
    /sha1 $thumbprint `
    /tr "http://timestamp.digicert.com" `
    /td SHA256 `
    /fd SHA256 `
    /d "DBC Parser" `
    $exe
```

### Automated Signing Script

Create `sign-windows.ps1`:

```powershell
#!/usr/bin/env pwsh
param(
    [Parameter(Mandatory=$true)]
    [string]$CertPath,
    
    [Parameter(Mandatory=$true)]
    [string]$Password,
    
    [string]$Timestamp = "http://timestamp.digicert.com"
)

$ErrorActionPreference = "Stop"

# Find signtool
$signtool = Get-ChildItem "C:\Program Files (x86)\Windows Kits\10\bin" -Recurse -Filter "signtool.exe" |
    Where-Object { $_.FullName -match "x64" } |
    Sort-Object -Property LastWriteTime -Descending |
    Select-Object -First 1 -ExpandProperty FullName

if (-not $signtool) {
    Write-Error "signtool.exe not found. Please install Windows SDK."
}

Write-Host "Using signtool: $signtool"

# Files to sign
$files = @(
    "deploy\windows\appDBC_Parser.exe",
    "installer_output\DBC_Parser_Setup_*.exe"
)

foreach ($pattern in $files) {
    $matches = Get-ChildItem $pattern -ErrorAction SilentlyContinue
    foreach ($file in $matches) {
        Write-Host "Signing: $($file.Name)"
        
        & $signtool sign `
            /f $CertPath `
            /p $Password `
            /tr $Timestamp `
            /td SHA256 `
            /fd SHA256 `
            /d "DBC Parser" `
            /du "https://github.com/dnasso/DBCFileViewer" `
            $file.FullName
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Signed successfully" -ForegroundColor Green
            
            # Verify
            & $signtool verify /pa $file.FullName
        } else {
            Write-Error "Failed to sign $($file.Name)"
        }
    }
}
```

Usage:
```powershell
.\sign-windows.ps1 -CertPath "cert.pfx" -Password "your_password"
```

### Timestamp Servers

Use timestamp servers to ensure signatures remain valid after certificate expires:

- DigiCert: `http://timestamp.digicert.com`
- Sectigo: `http://timestamp.sectigo.com`
- GlobalSign: `http://timestamp.globalsign.com`

### Verify Signed Executable

```powershell
# Verify with signtool
signtool verify /pa deploy\windows\appDBC_Parser.exe

# View signature details
Get-AuthenticodeSignature deploy\windows\appDBC_Parser.exe | Format-List

# Check signature in Explorer
# Right-click exe → Properties → Digital Signatures tab
```

---

## Linux Code Signing (GPG/PGP)

### Prerequisites

1. **Install GPG**
   ```bash
   # Ubuntu/Debian
   sudo apt install gnupg
   
   # Fedora
   sudo dnf install gnupg
   
   # Arch
   sudo pacman -S gnupg
   ```

2. **Generate GPG Key Pair**
   ```bash
   # Generate key (follow prompts)
   gpg --full-generate-key
   
   # Choose:
   # - Kind: RSA and RSA
   # - Size: 4096 bits
   # - Expiration: 2 years (recommended)
   # - Name: Your Name
   # - Email: your@email.com
   
   # List keys
   gpg --list-keys
   ```

### Signing AppImages

```bash
#!/bin/bash
# sign-appimage.sh

APPIMAGE="$1"
KEY_ID="your@email.com"  # Or use key fingerprint

if [ ! -f "$APPIMAGE" ]; then
    echo "Usage: $0 <appimage-file>"
    exit 1
fi

echo "Signing $APPIMAGE with GPG..."

# Create detached signature
gpg --detach-sign --armor --output "${APPIMAGE}.sig" "$APPIMAGE"

if [ $? -eq 0 ]; then
    echo "✓ Signature created: ${APPIMAGE}.sig"
    
    # Embed signature in AppImage (optional)
    echo "Embedding signature..."
    # This requires appimagetool
    # appimagetool --sign "$APPIMAGE"
    
    echo ""
    echo "Distribute both files:"
    echo "  - $APPIMAGE"
    echo "  - ${APPIMAGE}.sig"
fi
```

### Signing Flatpaks

Flatpak signing is done during bundle creation:

```bash
#!/bin/bash
# sign-flatpak.sh

REPO_DIR="flatpak-repo"
APP_ID="com.qtdevs.DBCParser"
GPG_KEY="your@email.com"

# Sign repository
flatpak build-sign "$REPO_DIR" --gpg-sign="$GPG_KEY"

# Create signed bundle
flatpak build-bundle "$REPO_DIR" dbc-parser.flatpak "$APP_ID" --gpg-sign="$GPG_KEY"

echo "✓ Flatpak signed and bundled"
```

### Publishing Your GPG Public Key

```bash
# Export public key
gpg --armor --export your@email.com > public-key.asc

# Upload to keyserver
gpg --send-keys YOUR_KEY_ID

# Or upload to multiple servers
gpg --keyserver keyserver.ubuntu.com --send-keys YOUR_KEY_ID
gpg --keyserver keys.openpgp.org --send-keys YOUR_KEY_ID
```

Users can then verify with:
```bash
# Import your public key
curl -s https://yoursite.com/public-key.asc | gpg --import

# Verify AppImage
gpg --verify DBC_Parser-x86_64.AppImage.sig DBC_Parser-x86_64.AppImage
```

---

## macOS Code Signing

### Prerequisites

1. **Apple Developer Account** ($99/year)
2. **Developer ID Certificate**
   - Download from Apple Developer portal
   - Install in Keychain

### Signing

```bash
# Sign the .app bundle
codesign --deep --force --verify --verbose \
    --sign "Developer ID Application: Your Name (TEAM_ID)" \
    --options runtime \
    DBC_Parser.app

# Verify signature
codesign --verify --verbose DBC_Parser.app

# Check details
codesign -dv --verbose=4 DBC_Parser.app
```

### Notarization (Required for macOS 10.15+)

```bash
# Create ZIP for notarization
ditto -c -k --keepParent DBC_Parser.app DBC_Parser.zip

# Submit to Apple
xcrun notarytool submit DBC_Parser.zip \
    --apple-id "your@email.com" \
    --team-id "TEAM_ID" \
    --password "app-specific-password" \
    --wait

# Staple ticket to app
xcrun stapler staple DBC_Parser.app
```

---

## Best Practices

### Security

1. **Never commit certificates/keys to version control**
   ```bash
   # Add to .gitignore
   *.pfx
   *.p12
   *.pem
   *.key
   *_private.key
   ```

2. **Store certificates securely**
   - Use environment variables for CI/CD
   - Use secret management (Azure Key Vault, AWS Secrets Manager)
   - Encrypt certificate files when storing

3. **Use strong passwords**
   - Minimum 16 characters
   - Mix of letters, numbers, symbols

### CI/CD Integration

#### GitHub Actions Example

```yaml
name: Build and Sign

on:
  release:
    types: [created]

jobs:
  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build
        run: |
          cmake -B build -DCMAKE_BUILD_TYPE=Release
          cmake --build build --config Release
      
      - name: Deploy
        run: .\deploy-windows.ps1
      
      - name: Decode Certificate
        run: |
          $pfx_bytes = [System.Convert]::FromBase64String($env:CERT_BASE64)
          [IO.File]::WriteAllBytes("cert.pfx", $pfx_bytes)
        env:
          CERT_BASE64: ${{ secrets.WINDOWS_CERT_BASE64 }}
      
      - name: Sign
        run: |
          .\sign-windows.ps1 -CertPath cert.pfx -Password $env:CERT_PASSWORD
        env:
          CERT_PASSWORD: ${{ secrets.CERT_PASSWORD }}
      
      - name: Upload
        uses: actions/upload-artifact@v3
        with:
          name: signed-windows-build
          path: deploy/windows/
```

### Certificate Management

1. **Backup certificates** to secure locations
2. **Set calendar reminders** for renewal (90 days before expiry)
3. **Test certificates** in clean VM before distribution
4. **Document** certificate details (issuer, expiry, thumbprint)

### Verification Checklist

Before distribution:

- [ ] Executable signed successfully
- [ ] Installer signed successfully
- [ ] Timestamp added (signature survives cert expiry)
- [ ] Verified on clean Windows/Linux system
- [ ] No security warnings when running
- [ ] Certificate details visible in properties
- [ ] All DLLs/libraries signed (Windows)

---

## Cost Comparison

| Certificate Type | Annual Cost | Trust Level | Use Case |
|-----------------|-------------|-------------|----------|
| Self-Signed | Free | Low (warnings) | Testing only |
| Standard Code Signing | $179-474 | Medium | General distribution |
| EV Code Signing | $599+ | High | Immediate SmartScreen trust |
| Apple Developer | $99 | High (macOS) | Mac app distribution |

### Recommendations

- **Open Source Projects**: Standard code signing certificate
- **Commercial Software**: EV certificate for better SmartScreen reputation
- **Internal Tools**: Self-signed (or no signing if trusted network)
- **Enterprise**: Company-issued certificates from internal CA

---

## Troubleshooting

### Windows

**"signtool.exe not found"**
- Install Windows SDK
- Check path: `C:\Program Files (x86)\Windows Kits\10\bin\<version>\x64\signtool.exe`

**"Certificate not trusted"**
- Ensure certificate chain is complete
- Verify CA certificate is in Windows Trusted Root store

**Timestamp fails**
- Try alternative timestamp servers
- Check internet connection
- Retry with longer timeout

### Linux

**"gpg: signing failed: No secret key"**
- List keys: `gpg --list-secret-keys`
- Ensure key is not expired
- Check key ID matches

**"Can't check signature: No public key"**
- Import public key first
- Verify key ID is correct

---

## Additional Resources

- [Microsoft Authenticode](https://docs.microsoft.com/en-us/windows-hardware/drivers/install/authenticode)
- [GPG Manual](https://www.gnupg.org/documentation/manuals/gnupg/)
- [Apple Notarization](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Flatpak Signing](https://docs.flatpak.org/en/latest/signing.html)
