//
//  MBXRasterTileOverlay.h
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

@import Foundation;
@import MapKit;

#import "MBXConstantsAndTypes.h"

@class MBXRasterTileOverlay;
@class MBXOfflineMapDatabase;

#pragma mark - Constants for the MBXMapKit error domain

extern NSString *const MBXMapKitErrorDomain;
extern NSInteger const MBXMapKitErrorCodeHTTPStatus;
extern NSInteger const MBXMapKitErrorCodeDictionaryMissingKeys;

#pragma mark - Delegate callbacks for asynchronous loading of map metadata and markers

/** The `MBXRasterTileOverlayDelegate` protocol provides notifications about asynchronous loading of map metadata and markers for raster image-based maps when using the `MBXRasterTileOverlay` class. */
@protocol MBXRasterTileOverlayDelegate <NSObject>

@optional

/** @name Observing Download Completion */

/** Notifies the delegate that asynchronous loading of the maps's metadata JSON is complete. This is designed to facilitate setting an `MKMapView`'s center point, initial zoom, and zoom limits.
*   @param overlay The raster tile overlay which has loaded its metadata JSON.
*   @param metadata The metadata JSON dictionary. This value may be `nil` if there was an error.
*   @param error The error encountered. This is `nil` unless there was an error. */
- (void)tileOverlay:(MBXRasterTileOverlay *)overlay didLoadMetadata:(NSDictionary *)metadata withError:(NSError *)error;

/** Notifies the delegate that asynchronous loading of the maps's marker JSON and associated marker icons are complete. This is designed to facilitate adding the array of markers to an `MKMapView`.
*   @param overlay The raster tile overlay which has loaded its markers.
*   @param markers An array of `MBXPointAnnotation` objects created by parsing the map's marker JSON and loading any referenced marker icons from the Mapbox API. This can be `nil` if the map has no markers or if there was an error.
*   @param error The error encountered. This is `nil` unless there was an error. */
- (void)tileOverlay:(MBXRasterTileOverlay *)overlay didLoadMarkers:(NSArray *)markers withError:(NSError *)error;

/** Notifies the delegate that there is no more asynchronous work to be done in order to load the map's metadata and markers. This is designed to facilitate hiding a network activity indicator.
*   @param overlay The raster tile overlay which is finished loading metadata and markers. */
- (void)tileOverlayDidFinishLoadingMetadataAndMarkers:(MBXRasterTileOverlay *)overlay;

/** Notifies the delegate that the map has finished rendering all visible tiles. 
*   @param overlay The raster tile overlay that was rendering its tiles. 
*   @param fullyRendered This parameter is set to `YES` if the overlay was able to render all tiles completely or `NO` if errors prevented all tiles from being rendered. */
- (void)tileOverlayDidFinishRendering:(MBXRasterTileOverlay *)overlay fullyRendered:(BOOL)fullyRendered;

@end


#pragma mark -

/** The `MBXRasterTileOverlay` class provides an `MKTileOverlay` subclass instance which loads Mapbox-hosted custom-styled map tiles, either live from Mapbox.com, or in offline mode using an `MBXOfflineMapDatabase` instance.
*
*   You can use an `MBXRasterTileOverlay` instance with an `MKMapView` map as you would any other `MKTileOverlay`. In particular, the use of multiple overlays on an `MKMapView` is supported as long as the proper values of `canReplaceMapContent` are set for each. Also, it is not possible to change the map ID of an overlay once it has been initialized, but you can easily add and remove overlays using the methods provided by `MKMapView`.
*
*   @warning Please note that you are responsible for getting permission to use the map data, and for ensuring your use adheres to the relevant terms of use.
*
*   @warning To avoid crashes in `MKMapView` due to asynchronous completion handlers referencing objects that no longer exist, it is very important to call the `invalidateAndCancel` method before removing an `MBXRasterTileOverlay` from your `MKMapView`. */
@interface MBXRasterTileOverlay : MKTileOverlay


#pragma mark - Map tile overlay layer initialization and configuration

/** @name Initializing a Tile Overlay */

/** Initialize a map view with a given Mapbox map ID, automatically loading metadata and markers.
*
*   By default, `canReplaceMapContent` will be set to `YES`, which means Apple's maps will be hidden, and if the map ID represents a map with partial-world coverage, areas for which the map has no tiles will appear blank. If you have a full-world map with transparency and wish to show Apple's maps below it, set `canReplaceMapContent` to `NO` before adding your overlay to an `MKMapView`.
*
*   Also by default, asynchronous network requests will be started to load the metadata (center coordinate, zoom, etc) and markers associated with your map ID, if there are any. To receive notification when the asynchronous requests complete, set a delegate which implements `MBXRasterTileOverlayDelegate`.
*
*   In order for the tile overlay to appear on your map, you must implement `-[MKMapViewDelegate mapView:rendererForOverlay:]` and return an instance of `MBXRasterTileRenderer`.
*
*   In order for markers to appear on your map, you must implement `-[MKMapViewDelegate mapView:viewForAnnotation:]` and return an `MKAnnotationView` initialized from an `MBXPointAnnotation`, including the `image` property.
*
*   @param mapID The Mapbox map ID.
*   @return An initialized raster tile overlay, or `nil` if an overlay could not be initialized. */
- (instancetype)initWithMapID:(NSString *)mapID;

/** Initialize a map view with a given Mapbox map ID while specifying whether to load metadata and markers.
*   @param mapID The Mapbox map ID.
*   @param includeMetadata Whether to load the map's metadata including center coordinate and zoom limits
*   @param includeMarkers Whether to load the map's markers
*   @return An initialized raster tile overlay, or `nil` if an overlay could not be initialized. */
- (instancetype)initWithMapID:(NSString *)mapID includeMetadata:(BOOL)includeMetadata includeMarkers:(BOOL)includeMarkers;

/** Initialize a map view with a given Mapbox map ID while specifying whether to load metadata, whether to load markers, which image quality to request, and which user agent string to use.
*   @param mapID The Mapbox map ID.
*   @param includeMetadata Whether to load the map's metadata including center coordinate and zoom limits
*   @param includeMarkers Whether to load the map's markers
*   @param imageQuality The image quality to use for requesting tiles
*   @return An initialized raster tile overlay, or `nil` if an overlay could not be initialized. */
- (instancetype)initWithMapID:(NSString *)mapID includeMetadata:(BOOL)includeMetadata includeMarkers:(BOOL)includeMarkers imageQuality:(MBXRasterImageQuality)imageQuality;

/** Initialize from an `MBXOfflineMapDatabase` object, using its stored values for metadata and markers, if it has any
*   @param offlineMapDatabase An offline map database object obtained from `MBXOfflineMapDownloader`
*   @return An initialized raster tile overlay, or `nil` if an overlay could not be initialized. */
- (instancetype)initWithOfflineMapDatabase:(MBXOfflineMapDatabase *)offlineMapDatabase;

/** @name Accessing the Delegate */

/** Delegate to notify of asynchronous resource load completion events. */
@property (weak, nonatomic) id<MBXRasterTileOverlayDelegate> delegate;

/** @name Invalidating a Tile Overlay */

/** Mark a tile overlay as invalidated and cancel any asynchronous completion handlers for resource downloads. */
- (void)invalidateAndCancel;


#pragma mark - Properties to check initialized values

/** @name Getting and Setting Properties */

/** A Boolean value that indicates whether the tile content is fully opaque.
*
*   If the tile content you provide can cover the entire drawing area with opaque content, set this property to `YES`. Doing so serves as a hint to the map view that it does not need to draw any additional content underneath your tiles. Set this property to `NO` if your tiles contain any transparency.
*
*   The default value for this property is `YES`. */
@property (nonatomic) BOOL canReplaceMapContent;

/** The map ID with which this raster tile overlay was initialized. */
@property (readonly,nonatomic) NSString *mapID;
/** The map's center coordinate as parsed from the metadata JSON. */
@property (readonly,nonatomic) CLLocationCoordinate2D center;
/** The map's initial zoom level as parsed from the metadata JSON.  */
@property (readonly,nonatomic) NSInteger centerZoom;
/** The map's array of `MBXPointAnnotation` marker annotations as parsed from the marker JSON. */
@property (readonly,nonatomic) NSArray *markers;
/** A default plain text attribution message suitable for displaying in an alert dialog. */
@property (readonly,nonatomic) NSString *attribution;


#pragma mark - Methods for invalidating cached metadata and markers

/** @name Clearing Cached Resources */

/** Clear only the cached Metadata JSON (map center point, zoom limits, etc) */
- (void)clearCachedMetadata;

/** Clear only the cached Markers JSON */
- (void)clearCachedMarkers;


@end
