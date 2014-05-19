//
//  MBXError.h
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import "MBXOfflineMapDatabase.h"
#import "MBXOfflineMapDownloader.h"
#import "MBXPointAnnotation.h"
#import "MBXRasterTileOverlay.h"
#import "MBXConstantsAndTypes.h"


/** A category on MKMapView adding the ability to set a Mapbox.js style initial center point and zoom */
@interface MKMapView (MBXMapView)

/** Convenience method to set an MKMapView's center point and zoom
 @param centerCoordinate The map's desired center coordinate
 @param zoomLevel The map's desired zoom level
 @param animated Whether the transition should be animated
 */
- (void)setCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate zoomLevel:(NSUInteger)zoomLevel animated:(BOOL)animated;

@end