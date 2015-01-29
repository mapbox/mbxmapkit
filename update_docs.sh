#!/bin/sh

if [ -z `which appledoc` ]; then
    echo "Unable to find appledoc. Consider installing it from source or Homebrew."
    exit 1
fi

OUTPUT="/tmp/`uuidgen`"

VERSION=$( git tag | sort -r | sed -n '1p' )
echo "Creating new docs for $VERSION..."
echo

appledoc \
    --output $OUTPUT \
    --project-name "MBXMapKit $VERSION" \
    --project-company Mapbox \
    --create-html \
    --no-create-docset \
    --no-install-docset \
    --company-id com.mapbox \
    --ignore .m \
    --index-desc README.md \
    .

rm -rf ./api
mkdir ./api
mv -v $OUTPUT/html/* ./api
