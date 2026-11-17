#!/bin/sh
# Copy the repo .env into this build so the iPhone app can read the OpenRouter
# key. The key is not in source, and this file is not committed. iOS apps cannot
# read the repo folder at runtime, so the copy happens here, on your Mac.
set -eu
DEST="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
mkdir -p "$DEST"
SRC="${SRCROOT}/../.env"
TMP=$(mktemp)
if [ -f "$SRC" ]; then
  grep -E '^[[:space:]]*(OPENROUTER_API_KEY|HEYA_MODEL)[[:space:]]*=' "$SRC" > "$TMP" || true
fi
if [ ! -s "$TMP" ]; then
  printf '%s\n' 'OPENROUTER_API_KEY=' > "$TMP"
fi
mv "$TMP" "$DEST/local.env"
