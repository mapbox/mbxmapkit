//
//  MBXMBTilesOverlay.h
//  MBTiles Sample Project
//
//  MBXMapKit Copyright (c) 2013-2015 Mapbox. All rights reserved.
//

#import <MapKit/MapKit.h>

/** The `MBXMBTilesOverlay` class provides an `MKTileOverlay` subclass instance which loads custom-styled map tiles from an MBTiles file and provides overzooming for zoom levels beyond the MBTiles file's maximum zoom level.
 *
 *   You can use an `MBXMBTilesOverlay` instance with an `MKMapView` map as you would any other `MKTileOverlay`. In particular, the use of multiple overlays on an `MKMapView` is supported as long as the proper values of `canReplaceMapContent` are set for each.
 *
 *   `MBXMBTilesOverlay` provides overzooming. When `loadTileAtPath:result:` receives a request for tiles at a higher zoom than the MBTiles file's maximum zoom level, it will an appropriately scaled and cropped sub-tile from the MBTiles file's maximum zoom level. Note that if the MBTiles file's metadata table provides an inaccurate maximum zoom level, overzooming will not work.
 *
 *   In order for the tile overlay to appear on your map, your `MKMapView`'s delegate must implement `mapView:rendererForOverlay:` from the `MKMapViewDelegate` protocol. If you want an MBTile overlay to be transparent, you can implement logic in `mapView:rendererForOverlay:` to identify that `MBXMBTiles` object and return an `MKTileOverlayRenderer` with its `alpha` property set to something other than 1.
 *
 *   @warning Please note that you are responsible for getting permission to use the map data, and for ensuring your use adheres to the relevant terms of use.
 *
 */
@interface MBXMBTilesOverlay : MKTileOverlay

/** @name Initializing a Tile Overlay */

/** Initialize an overzooming MBTiles tile overlay with the given MBTiles file path.
 *
 *   By default, `canReplaceMapContent` will be set to `NO`, which means this MBTiles overlay layer will not prevent Apple's map from loading. If you don't want Apple's basemap to load, just set `canReplaceMapContent` to 'YES' after this overlay is initialized but before adding it to an `MKMapView`.
 *
 *   @param mbtilesPath The path to an mbtiles file on the local disk.
 *   @return An initialized tile overlay, or `nil` if an overlay could not be initialized.
 */
- (id)initWithMBTilesPath:(NSString *)mbtilesPath;


/** @name MBTiles metadata */

/** Attribution string from the MBTiles metadata table */
@property (readonly, nonatomic) NSString *attribution;

/** Maximum zoom from the MBTiles metadata table */
@property (readonly, nonatomic) NSInteger mbtilesMaxZoom;

@end
