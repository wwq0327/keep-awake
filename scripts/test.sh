#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

# CLT includes Swift Testing but SwiftPM does not add its framework path.
# Its bundled Testing framework requires macOS 14; the app still targets 13.
frameworks="$(xcode-select -p)/Library/Developer/Frameworks"
if [ -d "$frameworks/Testing.framework" ]; then
    swift test --disable-xctest \
        -Xswiftc -F -Xswiftc "$frameworks" \
        -Xswiftc -target -Xswiftc "$(uname -m)-apple-macosx14.0" \
        -Xlinker -rpath -Xlinker "$frameworks" "$@"
else
    swift test --disable-xctest "$@"
fi
