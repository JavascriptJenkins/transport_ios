#!/usr/bin/env bash
# End-to-end App Store deploy: bump build, archive, export, upload.
#
# Requires an App Store Connect API key, set via env vars:
#   ASC_API_KEY_ID      — Key ID (10-char, e.g. "XYZ1234567")
#   ASC_API_ISSUER_ID   — Issuer UUID (from App Store Connect → Keys tab header)
#   ASC_API_KEY_PATH    — Path to AuthKey_<KeyID>.p8 on disk
#
# Typical local setup (add to ~/.zshrc or keep in a gitignored .env file):
#   export ASC_API_KEY_ID="XYZ1234567"
#   export ASC_API_ISSUER_ID="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
#   export ASC_API_KEY_PATH="$HOME/.appstoreconnect/keys/AuthKey_XYZ1234567.p8"
#
# Usage: ./scripts/deploy.sh
# Or with a specific marketing version: MARKETING_VERSION=1.0.1 ./scripts/deploy.sh

set -euo pipefail

cd "$(dirname "$0")/.."

: "${ASC_API_KEY_ID:?missing — get from App Store Connect → Users & Access → Integrations}"
: "${ASC_API_ISSUER_ID:?missing — header of the Keys tab in App Store Connect}"
: "${ASC_API_KEY_PATH:?missing — path to AuthKey_<KeyID>.p8}"
[ -f "$ASC_API_KEY_PATH" ] || { echo "key file not found: $ASC_API_KEY_PATH" >&2; exit 1; }

PROJECT="BuneIOS.xcodeproj"
SCHEME="BuneIOS"
ARCHIVE_PATH="build/BuneIOS.xcarchive"
EXPORT_DIR="build/export"
EXPORT_OPTIONS="scripts/ExportOptions.plist"

# 1. Bump build number from git commit count
./scripts/bump-build.sh

# 2. Optionally set marketing version
if [ -n "${MARKETING_VERSION:-}" ]; then
    xcrun agvtool new-marketing-version "$MARKETING_VERSION" >/dev/null
    echo "marketing version -> $MARKETING_VERSION"
fi

# 3. Clean previous archive / export
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"

# 4. Archive
echo "→ archiving..."
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    -authenticationKeyID "$ASC_API_KEY_ID" \
    -authenticationKeyIssuerID "$ASC_API_ISSUER_ID" \
    -authenticationKeyPath "$ASC_API_KEY_PATH" \
    archive

# 5. Export signed .ipa
echo "→ exporting .ipa..."
xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -allowProvisioningUpdates \
    -authenticationKeyID "$ASC_API_KEY_ID" \
    -authenticationKeyIssuerID "$ASC_API_ISSUER_ID" \
    -authenticationKeyPath "$ASC_API_KEY_PATH"

IPA=$(find "$EXPORT_DIR" -name "*.ipa" -maxdepth 2 | head -1)
[ -n "$IPA" ] || { echo "no .ipa produced" >&2; exit 1; }
echo "→ built: $IPA"

# 6. Upload via altool (uses the same API key; the -exportOptionsPlist
#    method=app-store-connect + destination=upload would also upload
#    automatically, but running altool explicitly gives clearer output).
echo "→ uploading to App Store Connect..."
xcrun altool \
    --upload-app \
    --file "$IPA" \
    --type ios \
    --apiKey "$ASC_API_KEY_ID" \
    --apiIssuer "$ASC_API_ISSUER_ID"

echo "✓ upload complete — processing in App Store Connect takes 10-30 min."
echo "  check status at https://appstoreconnect.apple.com → My Apps → BuneIOS → TestFlight"
