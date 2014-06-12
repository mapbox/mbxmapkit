//
//  MBXMapKit.h
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

#import "MBXConstantsAndTypes.h"
#import "MBXOfflineMapDatabase.h"
#import "MBXOfflineMapDownloader.h"
#import "MBXPointAnnotation.h"
#import "MBXRasterTileOverlay.h"

#pragma mark - MKMapView category

/** This category adds methods to the MapKit framework’s `MKMapView` class. */
@interface MKMapView (MBXMapKit)

/** @name Manipulating the Visible Portion of the Map */

/** Changes the center coordinate and zoom level of the map and optionally animates the change.
*   @param centerCoordinate The new center coordinate for the map.
*   @param zoomLevel The new zoom level for the map.
*   @param animated Specify `YES` if you want the map view to scroll to the new location or `NO` if you want the map to display the new location immediately. */
- (void)mbx_setCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate zoomLevel:(NSUInteger)zoomLevel animated:(BOOL)animated;

@end

#pragma mark - MBXMapKit global settings

@interface MBXMapKit : NSObject

/** @name Setting the User Agent for Mapbox API calls */

/** Access and change the global user agent for Mapbox API HTTP requests using the library.
*
*   If unset, defaults to `MBXMapKit` followed by the library version, generic hardware model, and software version information.
*
*   Example: `MyMapApp/1.2` */
+ (void)setUserAgent:(NSString *)userAgent;
+ (NSString *)userAgent;

@end
