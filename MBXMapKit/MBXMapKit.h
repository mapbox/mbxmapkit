//
//  MBXMapKit.h
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


/** Category methods on `MKMapView`. */
@interface MKMapView (MBXMapView)


/** Changes the center coordinate and zoom level of the map and optionally animates the change.
*   @param centerCoordinate The new center coordinate for the map.
*   @param zoomLevel The new zoom level for the map.
*   @param animated Specify `YES` if you want the map view to scroll to the new location or `NO` if you want the map to display the new location immediately. */
- (void)setCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate zoomLevel:(NSUInteger)zoomLevel animated:(BOOL)animated;

@end