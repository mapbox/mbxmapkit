Changelog
---------

### 0.6.0
#### February 3, 2015

- Re-added support for Mapbox `v4` API and [access tokens](https://www.mapbox.com/developers/api/#access-tokens) in tile and metadata requests. See `MBXMapKit.setAccessToken()`. 
- Added a new `MBXRasterTileRenderer` replacement for `MKTileOverlayRenderer` to support `512px` raster tiles and work around some iOS bugs. 
- Added a category method on `MKMapView` for obtaining the current zoom level. See `MKMapView.mbx_zoomLevel`. 
- Added a delegate callback for tile overlay rendering completion, similar to `MKMapViewDelegate.mapViewDidFinishRenderingMap(_, fullyRendered)`. See `MBXRasterTileOverlayDelegate.tileOverlayDidFinishRendering(_, fullyRendered)`. 
- Fixed a bug with setting the zoom level in a category method. 
- Updated the way that deprecated methods and properties are marked. 
- Documentation improvements. 

### 0.5.0
#### September 4, 2014

- Temporarily removed support for Mapbox `v4` API and [access tokens](https://www.mapbox.com/developers/api/#access-tokens) in tile and metadata requests.

### 0.4.0
#### August 14, 2014

- Added support for Mapbox `v4` API and [access tokens](https://www.mapbox.com/developers/api/#access-tokens) in tile and metadata requests. 
- Added `uniqueID` property to offline map databases for use when multiple regions with the same `mapID` are saved. 
- Added `creationDate` reference property to offline map databases. 
- Now ensures that all Mapbox API requests are over HTTPS. 
- Moved to `@import` modules for UIKit/AppKit linking requirements. 
- Fixed a bug with marker icon request URL formatting. 
- Some light refactoring. 

### 0.3.0
#### June 12, 2014

- Major refactor of styling integration. 
    - Instead of providing an `MBXMapView` subclass of Apple's `MKMapView`, there is now a `MBXRasterTileOverlay` class which can be added directly to a stock `MKMapView` just like Apple's `MKTileOverlay`. 
    - `MBXRasterTileOverlay` has support for Mapbox map IDs and optionally setting the map center and zoom from Mapbox metadata as well as optionally auto-adding server-specified (Mapbox simplestyle) markers. 
    - Includes a new `MBXRasterTileOverlayDelegate` protocol for callbacks pertaining to asynchronous marker and metadata loading, including errors received. 
- First-class offline map database creation and subsequent use with `MBXOfflineMapDownloader` and its `MBXOfflineMapDatabase` document objects. 
    - Includes optional support for saving offline JSON metadata and marker imagery as well. 
    - Includes a new `MBXOfflineMapDownloaderDelegate` protocol for receiving updates to downloader progress and state, including errors received. 
- Support for `NSURLCache` shared performance cache for network requests, which is now separate and distinct from offline map functionality. 
- Added class `MBXPointAnnotation` for easier custom imagery. Used by `MBXRasterTileOverlay` when auto-adding Mapbox markers. 
- Global, configurable user agent for Mapbox API requests with `+[MBXMapKit setUserAgent:]`. 
- Prefixed category methods on Apple classes with `mbx_` for namespace safety. 
- Bug fixes and performance improvements. 

### 0.2.1
#### March 6, 2014

- Fixed a bug where a user-set map view delegate wasn't consulted for annotation views.

### 0.2.0
#### March 5, 2014

- Support for [simplestyle GeoJSON](https://www.mapbox.com/developers/api/maps/#geojson) markers bundled with Mapbox online maps.
- New `MBXPointAnnotation` class supporting the [Mapbox markers API](https://www.mapbox.com/developers/api/static/#markers).
- Added support for the [Mapbox image quality API](https://www.mapbox.com/developers/api/static/#format).
- Added handling for the `-initWithFrame:` default initializer.
- Updated example map to one that includes server-side markers.
- Improved handling of airplane mode and other offline scenarios.
- Improved documentation.
- Fixed a bug related to asynchronous layer loading overriding previously set starting center coordinate.
- Fixed a bug where a Mapbox map server-set center was not used in the library.
- Fixed a bug where non-HTTP 200 responses could get written to cache and added code to clean up previous instances of the bug.
- Fixed a bug where a custom caching interval was not respected during cache sweeps.

### 0.1.0
#### September 18, 2013

- Initial public release. 
