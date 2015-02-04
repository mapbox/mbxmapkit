//
//  MBXMapKit.h
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

@import Foundation;
@import MapKit;

#import "MBXConstantsAndTypes.h"
#import "MBXOfflineMapDatabase.h"
#import "MBXOfflineMapDownloader.h"
#import "MBXPointAnnotation.h"
#import "MBXRasterTileOverlay.h"
#import "MBXRasterTileRenderer.h"

#pragma mark - MKMapView category

/** This category adds methods to the MapKit framework’s `MKMapView` class. */
@interface MKMapView (MBXMapKit)

/** @name Manipulating the Visible Portion of the Map */

/** Changes the center coordinate and zoom level of the map and optionally animates the change.
*   @param centerCoordinate The new center coordinate for the map.
*   @param zoomLevel The new zoom level for the map. Acceptable values range from a minimium of `0` (full world, if able to be shown in the current `frame`) to a maximum of `20` (the highest detail that MapKit supports). 
*   @param animated Specify `YES` if you want the map view to scroll to the new location or `NO` if you want the map to display the new location immediately. */
- (void)mbx_setCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate zoomLevel:(NSUInteger)zoomLevel animated:(BOOL)animated;

/** Returns the current zoom level of the map. */
- (CGFloat)mbx_zoomLevel;

@end

#pragma mark - MBXMapKit global settings

/** Global convenience methods for the framework. */
@interface MBXMapKit : NSObject

/** @name Authorizing Access */

/** Sets the global access token for Mapbox API requests. Obtain an access token on your [Mapbox account page](https://www.mapbox.com/account/apps/). 
*   @param accessToken A Mapbox API access token. */
+ (void)setAccessToken:(NSString *)accessToken;

/** Returns the global access token for Mapbox API HTTP requests. */
+ (NSString *)accessToken;

/** @name Using a Custom User Agent */

/** Sets the global user agent for Mapbox API HTTP requests.
*
*   If unset, defaults to `MBXMapKit` followed by the library version, generic hardware model, and software version information.
*
*   Example: `MyMapApp/1.2`
*   @param userAgent The desired user agent string. */
+ (void)setUserAgent:(NSString *)userAgent;

/** Returns the global user agent for Mapbox API HTTP requests. */
+ (NSString *)userAgent;

@end
