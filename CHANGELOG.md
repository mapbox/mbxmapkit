Changelog
---------

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