@import MapKit;

@interface MBXRasterTileRenderer : MKOverlayRenderer

- (id)initWithTileOverlay:(MKTileOverlay *)tileOverlay;
- (void)reloadData;

@end
