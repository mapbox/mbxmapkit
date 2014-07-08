#!/bin/bash

HTMLTOP='<div id="header">'
HTMLEND='<div class="main-navigation navigation-bottom">'
YAML="\
---
title: MBXMapKit `git tag | sort -r | sed -n '1p'`
layout: api
permalink: /api
navigation:"
CONTENT=""

scrape() {
  FR=`grep -n "$HTMLTOP" $1 | grep -o [0-9]*`
  TO=`grep -n "$HTMLEND" $1 | grep -o [0-9]*`
  LINES=`echo "$TO - $FR" | bc`
  echo "$(tail -n +$FR $1 | head -n $LINES)"
}

YAML="$YAML\n  Classes:"
for file in `find /tmp/docset -wholename "*Classes/*.html" | sort`; do
  YAML="$YAML\n  - $(basename $file .html)-class"
  CONTENT="$CONTENT\n$(scrape $file)"
done

YAML="$YAML\n  Protocols:"
for file in `find /tmp/docset -wholename "*Protocols/*.html" | sort`; do
  YAML="$YAML\n  - $(basename $file .html)-protocol"
  CONTENT="$CONTENT\n$(scrape $file)"
done

echo -e "$YAML"
echo "---"
echo -e "$CONTENT" | \
  # Simplify CSS.
  sed 's,class="title ,class=",' | \
  sed 's,class="section ,class=",' | \
  # Add an id to <h2>'s so they can be looked up by anchor links.
  sed '/Class Reference/s,<h2>\([^<]*\)</h2>,<h2 id="\1-class">\1</h2>,' | \
  sed '/Protocol Reference/s,<h2>\([^<]*\)</h2>,<h2 id="\1-protocol">\1</h2>,' | \
  # Replace links to class/protocol pages with anchor links. Avoids http:// urls.
  sed 's,<a href="[^#\"]*Classes[^\"]*">\([^<]*\)</a>,<a href="#\1-class">\1</a>,g' | \
  sed 's,<a href="[^#\"]*Protocols[^\"]*">\([^<]*\)</a>,<a href="#\1-protocol">\1</a>,g' | \
  # Consider any pages left to also be protocols.
  sed 's,<a href="[^#\"]*\.html">\([^<]*\)</a>,<a href="#\1-protocol">\1</a>,g' | \
  # Simplify class/protocol titles.
  sed 's, Class Reference,,g' | \
  sed 's, Protocol Reference,,g' | \
  # Link header files to GitHub.
  sed 's,>\(.*\.h\)<,><a href="https://github.com/mapbox/mbxmapkit/blob/master/MBXMapKit/\1">\1</a><,'
