//
//  MBXMapKit.h
//  MBXMapKit
//
//  Created by Justin R. Miller on 9/4/13.
//  Copyright (c) 2013 MapBox. All rights reserved.
//

#import <MapKit/MapKit.h>

@protocol MBXMapViewCaching;

/** An MBXMapView provides an embeddable map interface, similar to the one provided by Apple's MapKit, with support for MapBox-hosted custom map styles. You use this class to display map information and to manipulate the map contents from your application.
*
*   @warning Please note that you are responsible for getting permission to use the map data, and for ensuring your use adheres to the relevant terms of use. */
@interface MBXMapView : MKMapView

/** @name Initializing a Map View */

/** Initialize a map view with a given frame and MapBox map ID.
*
*   By default, Apple's maps will be hidden if the map ID represents a full-world map and shown if the map ID represents a map with partial-world coverage. If you have a full-world map with transparency and wish to show Apple's maps below it, use the initWithFrame:mapID:showDefaultBaseLayer: with a `showDefaultBaseLayer` value of `YES`. 
*
*   If you set a `delegate` on the map view (adopting the `MKMapViewDelegate` protocol), you do not need to return a renderer for `mapView:rendererForOverlay:` in order to render the MapBox overlay. However, if you do implement that delegate method, you should return either a custom `MKTileOverlayRenderer` object or simply `nil` in response to the MapBox overlay in order to ensure proper display. 
*
*   @param frame The map view's frame.
*   @param mapID The MapBox map ID. 
*   @return An initialized map view, or `nil` if a map view was unable to be initialized. */
- (id)initWithFrame:(CGRect)frame mapID:(NSString *)mapID;

/** Initialize a map view with a given frame and map ID while specifying whether or not to load Apple's maps. 
*   @param frame The map view's frame.
*   @param mapID The MapBox map ID.
*   @param showDefaultBaseLayer Whether to hide or show Apple's default maps below the MapBox map.
*   @return An initialized map view, or `nil` if a map view was unable to be initialized. */
- (id)initWithFrame:(CGRect)frame mapID:(NSString *)mapID showDefaultBaseLayer:(BOOL)showDefaultBaseLayer;

/** @name Accessing Map Properties */

/** The MapBox map ID for the map view. 
*
*   Upon setting a new map ID, the map view will begin an asynchronous download of the hosted metadata for the map. When the download completes successfully, the map style will change to reflect the new map ID. */
@property (nonatomic, copy) NSString *mapID;

/** @name Manipulating the Visible Portion of the Map */

/** Changes the center coordinate and zoom level of the map and optionally animates the change. 
*   @param centerCoordinate The new center coordinate for the map.
*   @param zoomLevel The new zoom level for the map. 
*   @param animated Specify `YES` if you want the map view to scroll to the new location or `NO` if you want the map to display the new location immediately.
*
*   @see [MKTileOverlay minimumZ]
*   @see [MKTileOverlay maximumZ] */
- (void)setCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate zoomLevel:(NSUInteger)zoomLevel animated:(BOOL)animated;

/** @name Configuring Map Tile Caching */

/** Change the cache duration for MapBox tiles for all maps. The default behavior is to cache tiles for one week. 
*
*   Changing this property has no effect on any caching system managed by a cachingDelegate, but will trigger the removal of any expired tiles that were previously cached by the default caching system. */
@property (nonatomic) NSTimeInterval cacheInterval;

/** Remove any locally-cached MapBox tiles for the given map ID.
*
*   This method has no effect on any caching system managed by a cachingDelegate, but will still remove tiles that were previously cached by the default caching system.
*
*   @param mapID The MapBox map ID. */
- (void)emptyCacheForMapID:(NSString *)mapID;

/** Set a custom caching delegate. The caching delegate is consulted when map tiles are needed by the rendering system and is notified when new map tiles are downloaded from MapBox. The caching delegate should implement the methods in the MBXMapViewCaching protocol. */
@property (nonatomic, weak) IBOutlet id <MBXMapViewCaching>cachingDelegate;

@end

#pragma mark -

/** The MBXMapViewCaching protocol defines a set of optional methods that you can use to customize the MapBox tile caching behavior by using an external caching system. */
@protocol MBXMapViewCaching <NSObject>

@optional

/** @name Retrieving Cached Map Data */

/** Asks the caching delegate for image data for a map tile to render.
*   @param mapView The map view loading the tile. 
*   @param mapID The MapBox map ID. 
*   @param path The path structure that identifies the specific tile needed. This structure incorporates the tile’s X-Y coordinate at a given zoom level and scale factor. 
*   @return The tile image data to render. */
- (NSData *)mapView:(MBXMapView *)mapView loadCacheDataForMapID:(NSString *)mapID tilePath:(MKTileOverlayPath)path;

/** @name Saving Map Data to Cache */

/** Offers the caching delegate a chance to cache a downloaded map tile image. 
*   @param mapView The map view that downloaded the tile. 
*   @param tileData The tile image data. 
*   @param mapID The MapBox map ID. 
*   @param path The path structure that identifies the specific tile downloaded. This structure incorporates the tile’s X-Y coordinate at a given zoom level and scale factor. */
- (void)mapView:(MBXMapView *)mapView saveCacheData:(NSData *)tileData forMapID:(NSString *)mapID tilePath:(MKTileOverlayPath)path;

@end