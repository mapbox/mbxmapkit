## MBXMBTilesOverlay

The `MBXMBTilesOverlay` class provides an `MKTileOverlay` subclass instance
which loads custom-styled map tiles from an MBTiles file and provides
overzooming for zoom levels beyond the MBTiles file's maximum zoom level.

You can use an `MBXMBTilesOverlay` instance with an `MKMapView` map as you
would any other `MKTileOverlay`. In particular, the use of multiple overlays on
an `MKMapView` is supported as long as the proper values of
`canReplaceMapContent` are set for each overlay.

`MBXMBTilesOverlay` provides overzooming. When `loadTileAtPath:result:`
receives a request for tiles at a higher zoom than the MBTiles file's maximum
zoom level, it will an appropriately scaled and cropped sub-tile from the
MBTiles file's maximum zoom level. Note that if the MBTiles file's metadata
table provides an inaccurate maximum zoom level, overzooming will not work.

In order for the tile overlay to appear on your map, your `MKMapView`'s
delegate must implement `mapView:rendererForOverlay:` from the
`MKMapViewDelegate` protocol. If you want an MBTile overlay to be transparent,
you can implement logic in `mapView:rendererForOverlay:` to identify that
`MBXMBTiles` object and return an `MKTileOverlayRenderer` with its `alpha`
property set to something other than 1.

## Known Issues

Apple's internal implementation of MKMapKit for iOS 8 appears to include
regressions from the iOS 7 implementation. You may notice decreased tile
rendering performance, particularly on retina iPads, and a lot of additional
log messages. For more information and potential work-arounds, please refer
to the MBXMapKit [issues list](https://github.com/mapbox/mbxmapkit/issues).

