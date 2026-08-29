# Releasing OMacOS

Tagged releases are built by `.github/workflows/release.yml`. The workflow reruns the complete suite, imports a temporary Developer ID certificate, enables Hardened Runtime, signs the native app with the minimum audio-input entitlement required by dictation, submits the ZIP with `notarytool`, staples the accepted ticket, and publishes the immutable archive, checksum, and metadata.

Configure these GitHub Actions secrets before pushing a tag:

- `APPLE_CERTIFICATE_P12_BASE64`
- `APPLE_CERTIFICATE_PASSWORD`
- `APPLE_SIGNING_IDENTITY`
- `APPLE_NOTARY_PRIVATE_KEY_BASE64`
- `APPLE_NOTARY_KEY_ID`
- `APPLE_NOTARY_ISSUER_ID`

The tag without its leading `v` must match `VERSION`. For example, `VERSION=0.3.0` requires tag `v0.3.0`.

Local ad-hoc packaging is available for structural testing:

```bash
./scripts/package-release.zsh dist
```

An ad-hoc archive is not a public release. Apple requires a Developer ID signature, Hardened Runtime, secure timestamp, and notarization for normal direct distribution. OMacOS uses `notarytool`; it does not use the retired `altool` path. See Apple’s [notarization guidance](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) and [Hardened Runtime documentation](https://developer.apple.com/documentation/security/hardened-runtime).
