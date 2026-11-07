#!/usr/bin/env bash
# Starts the Firebase Emulator Suite for development: Auth, Firestore
# (with firestore.rules), Functions (the Last.fm / Deezer proxy in
# functions/), and the UI at http://127.0.0.1:4000. Then run the
# app against it:
#
#   flutter run --dart-define-from-file=config/dev.env
#   (set USE_EMULATORS=true in config/dev.env)
#
# Data is kept between runs in .emulator-data (git-ignored); delete it to
# start empty. Ctrl+C stops the emulators and saves it.
set -euo pipefail
cd "$(dirname "$0")/.."

# The Firebase CLI pinned with the rules tests.
firebase=tool/firestore_rules_test/node_modules/.bin/firebase
if [ ! -e "$firebase" ]; then
  (cd tool/firestore_rules_test && npm ci)
fi

# The backend, built; the emulator reads Last.fm's key from
# functions/.secret.local (git-ignored): put yours there for real answers.
if [ ! -d functions/node_modules ]; then
  (cd functions && npm ci)
fi
(cd functions && npm run build --silent)
if [ ! -f functions/.secret.local ]; then
  echo 'LASTFM_API_KEY=put-your-key-here' > functions/.secret.local
  echo "Created functions/.secret.local: add your Last.fm key for real answers."
fi

# The Firestore emulator needs Java 11 or newer: when the one on PATH is
# older, use the JDK that comes with Android Studio.
if ! java -version 2>&1 | grep -qE 'version "(1[1-9]|[2-9][0-9])'; then
  for jbr in "/c/Program Files/Android/Android Studio/jbr" \
             "/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
             "$HOME/android-studio/jbr" "/opt/android-studio/jbr"; do
    if [ -e "$jbr/bin/java" ] || [ -e "$jbr/bin/java.exe" ]; then
      export JAVA_HOME="$jbr" PATH="$jbr/bin:$PATH"
      break
    fi
  done
fi

# Every connected Android device, phone or emulator, reaches them at its own
# 127.0.0.1. Run this again after a device (re)connects.
if command -v adb >/dev/null; then
  for device in $(adb devices | awk 'NR > 1 && $2 == "device" { print $1 }'); do
    for port in 9099 8080 5001; do
      adb -s "$device" reverse "tcp:$port" "tcp:$port" >/dev/null
    done
    echo "Emulator ports forwarded to $device"
  done
fi

import=()
if [ -f .emulator-data/firebase-export-metadata.json ]; then
  import=(--import .emulator-data)
fi
exec "$firebase" emulators:start --only auth,firestore,functions \
  --project tsuki-tunes-dev "${import[@]}" --export-on-exit .emulator-data
