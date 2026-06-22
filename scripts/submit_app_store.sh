#!/usr/bin/env bash
# =============================================================================
# FocusFlow — App Store Submission Script
# =============================================================================
# Prerequisites:
#   1. Apple Developer Program membership ($99/year)
#   2. App Store Connect API Key (https://appstoreconnect.apple.com/access/api)
#       - Set env var APP_STORE_CONNECT_KEY_ID
#       - Set env var APP_STORE_CONNECT_ISSUER_ID
#       - Store .p8 key file at path set in APP_STORE_CONNECT_API_KEY_PATH
#   3. Xcode 15+ installed
#   4. Provisioning profile "FocusFlow App Store" installed in Xcode
#   5. App record created in App Store Connect (bundle: com.focusflow.app)
#
# Usage:
#   DEVELOPMENT_TEAM="ABCDE12345" ./scripts/submit_app_store.sh
#   DEVELOPMENT_TEAM="ABCDE12345" ./scripts/submit_app_store.sh --no-upload
# =============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/FocusFlow"
BUILD_DIR="$ROOT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/FocusFlow.xcarchive"
EXPORT_DIR="$BUILD_DIR/app-store-export"
EXPORT_OPTIONS="$ROOT_DIR/scripts/ExportOptions.plist"

# ---- Configuration ----
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"
APP_STORE_CONNECT_KEY_ID="${APP_STORE_CONNECT_KEY_ID:-}"
APP_STORE_CONNECT_ISSUER_ID="${APP_STORE_CONNECT_ISSUER_ID:-}"
APP_STORE_CONNECT_API_KEY_PATH="${APP_STORE_CONNECT_API_KEY_PATH:-}"
UPLOAD=true

for arg in "$@"; do
    case "$arg" in
        --no-upload) UPLOAD=false ;;
    esac
done

# ---- Validation ----

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ -z "$DEVELOPMENT_TEAM" ]; then
    echo -e "${RED}ERROR: DEVELOPMENT_TEAM not set.${NC}"
    echo "  Usage: DEVELOPMENT_TEAM=\"YOUR_TEAM_ID\" $0"
    exit 1
fi

echo -e "${GREEN}=== FocusFlow App Store Submission ===${NC}"
echo ""
echo "  Team ID:      $DEVELOPMENT_TEAM"
echo "  Bundle ID:    com.focusflow.app"
echo "  Upload:       $UPLOAD"
echo ""

# ---- Step 1: Generate the Xcode project from project.yml ----
echo -e "${YELLOW}[1/4]${NC} Generating Xcode project (XcodeGen)..."
if ! command -v xcodegen >/dev/null 2>&1; then
    echo -e "${RED}ERROR: xcodegen not installed. Run: brew install xcodegen${NC}"
    exit 1
fi
cd "$ROOT_DIR"
xcodegen generate
XCODEPROJ="$ROOT_DIR/FocusFlow.xcodeproj"

# ---- Step 2: Archive ----
echo -e "${YELLOW}[2/4]${NC} Creating xcarchive..."
rm -rf "$ARCHIVE_PATH"

xcodebuild archive \
    -project "$XCODEPROJ" \
    -scheme FocusFlow \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_STYLE="Manual" \
    CODE_SIGN_IDENTITY="Apple Distribution" \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    PROVISIONING_PROFILE_SPECIFIER="FocusFlow App Store" \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    | xcpretty || xcodebuild archive \
        -project "$XCODEPROJ" \
        -scheme FocusFlow \
        -destination 'generic/platform=macOS' \
        -archivePath "$ARCHIVE_PATH" \
        CODE_SIGN_STYLE="Manual" \
        CODE_SIGN_IDENTITY="Apple Distribution" \
        DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
        PROVISIONING_PROFILE_SPECIFIER="FocusFlow App Store"

echo -e "${GREEN}  ✓ Archive created: $ARCHIVE_PATH${NC}"

# ---- Step 3: Export for App Store ----
echo -e "${YELLOW}[3/4]${NC} Exporting for App Store distribution..."
rm -rf "$EXPORT_DIR"

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"

echo -e "${GREEN}  ✓ Exported to: $EXPORT_DIR${NC}"

# ---- Step 4: Validate & Upload ----
if [ "$UPLOAD" = true ]; then
    if [ -z "$APP_STORE_CONNECT_KEY_ID" ] || [ -z "$APP_STORE_CONNECT_ISSUER_ID" ]; then
        echo -e "${RED}ERROR: App Store Connect API credentials not set.${NC}"
        echo "  Set: APP_STORE_CONNECT_KEY_ID, APP_STORE_CONNECT_ISSUER_ID, APP_STORE_CONNECT_API_KEY_PATH"
        echo "  Skipping upload. Exported package is at: $EXPORT_DIR"
        exit 0
    fi

    if [ -z "$APP_STORE_CONNECT_API_KEY_PATH" ] || [ ! -f "$APP_STORE_CONNECT_API_KEY_PATH" ]; then
        echo -e "${RED}ERROR: APP_STORE_CONNECT_API_KEY_PATH does not point to a .p8 key file.${NC}"
        echo "  Exported package is at: $EXPORT_DIR"
        exit 1
    fi

    KEY_DIR="$HOME/.appstoreconnect/private_keys"
    ALTOOL_KEY_PATH="$KEY_DIR/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
    mkdir -p "$KEY_DIR"
    if [ "$APP_STORE_CONNECT_API_KEY_PATH" != "$ALTOOL_KEY_PATH" ]; then
        cp "$APP_STORE_CONNECT_API_KEY_PATH" "$ALTOOL_KEY_PATH"
    fi
    chmod 600 "$ALTOOL_KEY_PATH"

    PKG_FILE="$(ls "$EXPORT_DIR"/*.pkg 2>/dev/null || true)"
    if [ -z "$PKG_FILE" ]; then
        echo -e "${RED}ERROR: No .pkg found in export directory.${NC}"
        exit 1
    fi

    echo -e "${YELLOW}[4/4]${NC} Validating & uploading to App Store Connect..."
    echo "  Package: $PKG_FILE"

    # Validate first
    echo "  Validating..."
    xcrun altool --validate-app \
        -f "$PKG_FILE" \
        -t macos \
        --apiKey "$APP_STORE_CONNECT_KEY_ID" \
        --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"

    # Upload
    echo "  Uploading..."
    xcrun altool --upload-app \
        -f "$PKG_FILE" \
        -t macos \
        --apiKey "$APP_STORE_CONNECT_KEY_ID" \
        --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"

    echo -e "${GREEN}  ✓ Upload complete!${NC}"
else
    echo -e "${YELLOW}[4/4]${NC} Skipping upload (--no-upload)."
    echo "  Exported package: $EXPORT_DIR"
fi

echo ""
echo -e "${GREEN}=== Done ===${NC}"
echo "  Next steps:"
echo "  1. Visit https://appstoreconnect.apple.com"
echo "  2. Complete App Store listing (screenshots, description, etc.)"
echo "  3. Submit for review"
