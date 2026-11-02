#!/bin/bash
# Notarize and staple "밧줄 태우지 마라.app". Sends the app to Apple, so run only with the owner's OK.
# One-time setup (Apple ID + app-specific password, or an App Store Connect API key):
#   xcrun notarytool store-credentials multiturn-notary --apple-id <id> --team-id 8V3Z27Z6RY
set -euo pipefail
cd "$(dirname "$0")"
PROFILE="${1:-multiturn-notary}"
rm -f Rope-notarize.zip
ditto -c -k --keepParent "밧줄 태우지 마라.app" Rope-notarize.zip
xcrun notarytool submit Rope-notarize.zip --keychain-profile "$PROFILE" --wait
xcrun stapler staple "밧줄 태우지 마라.app"
spctl -a -vvv -t exec "밧줄 태우지 마라.app"
rm -f Rope-notarize.zip
