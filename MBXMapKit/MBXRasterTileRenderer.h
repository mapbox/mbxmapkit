//
//  MBXRasterTileRenderer.m
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

@import MapKit;

/** An `MBXRasterTileRenderer` object handles the drawing of tiles managed by an `MBXRasterTileOverlay` object. You create instances of this class when tile overlays become visible on the map view. A renderer works closely with its associated tile overlay object to coordinate the loading and drawing of tiles at appropriate times. */
@interface MBXRasterTileRenderer : MKOverlayRenderer

/** Initializes and returns a tile renderer with the specified overlay object.
*
*   The returned renderer object works with the tile overlay object to coordinate the loading and display of its map tiles.
*
*   @param overlay The tile overlay object whose contents you want to draw.
*   @return An initialized tile renderer object. */
- (instancetype)initWithTileOverlay:(MKTileOverlay *)overlay;

/** Forces tiles to be reloaded and displayed.
*
*   Use this method to remove the overlay’s existing tile images and reload them from the original source. This method automatically causes the renderer to redraw the new tiles as soon as they are loaded into memory. */
- (void)reloadData;

@end
