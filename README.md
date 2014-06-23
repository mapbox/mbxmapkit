### MBXMapKit Overview Documentation

The mb-pages branch has the [Jekyll](http://jekyllrb.com) source files for the
MBXMapKit Overview page at https://www.mapbox.com/mbxmapkit/ and the MBXMapKit
Examples page at https://www.mapbox.com/mbxmapkit/examples/


Source structure:
 * `/_layouts/*` are page templates (sidebar, header, etc)
 * `/index.html` is the overview landing page
 * `/_posts/2014-06-20-examples.html` is the examples landing page
 * `/_posts/examples/*` are the individual examples

### Running Jekyll Server

To preview your edits locally, you can do
```
jekyll serve --baseurl '/mbxmapkit'
```
from the root directory of the mb-pages branch. The `--baseurl` part is
important to ensure that all of the site CSS can load.

Once the pages have built and the server is running, you can load the overview
page at `0.0.0.0:4000/mbxmapkit/`. Note that the trailing `/` is required.

