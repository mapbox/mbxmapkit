#!/bin/sh

VERSION=$( git tag | sort -r | sed -n '1p' )

appledoc \
    --output Docs \
    --project-name "MBXMapKit $VERSION" \
    --project-company Mapbox \
    --create-html \
    --create-docset \
    --company-id com.mapbox \
    --ignore .m \
    --clean-output \
    --docset-install-path /tmp/docset \
    --index-desc README.md \
    --docset-atom-filename docset.atom \
    --docset-feed-url "http://mapbox.com/mbxmapkit/Docs/publish/%DOCSETATOMFILENAME" \
    --docset-package-url "https://github.com/mapbox/mbxmapkit/raw/packaging/Downloads/%DOCSETPACKAGEFILENAME" \
    --publish-docset \
    .
