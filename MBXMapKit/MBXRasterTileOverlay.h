//
//  MBXRasterTileOverlay.h
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

#import <MapKit/MapKit.h>
#import "MBXConstantsAndTypes.h"

@class MBXRasterTileOverlay;
@class MBXOfflineMapDatabase;


#pragma mark - Constants for the MBXMapKit error domain

extern NSString *const MBXMapKitErrorDomain;
extern NSInteger const MBXMapKitErrorCodeHTTPStatus;
extern NSInteger const MBXMapKitErrorCodeDictionaryMissingKeys;


#pragma mark - Delegate callbacks for asynchronous loading of map metadata and markers

/** Delegate callbacks for notifications about asynchronous loading of map metadata and markers */
@protocol MBXRasterTileOverlayDelegate <NSObject>

/** Notification that asynchronous loading of the maps's metadata JSON is complete. This is designed to facilitate setting an MKMapView's center point, initial zoom, and zoom limits.
 @param overlay The raster tile overlay which has loaded its metadata JSON
 @param metadata The metadata JSON dictionary. This might be `nil` if there was an error.
 @param error The error code. This is probably `nil` unless there was an error.
 */
- (void)tileOverlay:(MBXRasterTileOverlay *)overlay didLoadMetadata:(NSDictionary *)metadata withError:(NSError *)error;

/** Notification that asynchronous loading of the maps's marker JSON and associated marker icons are complete. This is designed to facilitate adding the array of markers to an MKMapView.
 @param overlay The raster tile overlay which has loaded its markers
 @param markers An array of MBXPointAnnotation marker annotations created by parsing the map's markers JSON and loading the any referenced marker icons from the Mapbox Core API. This can be `nil` if the map has no markers, or if there was an error.
 @param error The error code. This is probably `nil` unless there was an error.
 */
- (void)tileOverlay:(MBXRasterTileOverlay *)overlay didLoadMarkers:(NSArray *)markers withError:(NSError *)error;

/** Notification that there is no more asynchronous work to be done for loading the map's metadata and markers. This was designed to facilitate turning off a network activity indicator.
 @param overlay The raster tile overlay which is finished loading metadata and markers
 */
- (void)tileOverlayDidFinishLoadingMetadataAndMarkers:(MBXRasterTileOverlay *)overlay;

@end


#pragma mark -

/** An `MBXRasterTileOverlay` provides an `MKTileOverlay` subclass instance which loads Mapbox-hosted custom styled map tiles, either live from Mapbox.com, or in offline mode using an `MBXOfflineMapDatabase` instance. You can use an `MBXRasterTileOverlay` instance with an `MKMapView` map as you would any other `MKTileOverlay`. In particular, it's fine to add multiple overlays to an `MKMapView`, just be sure to set the `canReplaceMapContent` values appropriately. Also, it is not possible to "switch" the map ID of an overlay once it has been initialized, but you can easily add and remove overlays using the methods provided by `MKMapView`. To avoid possible crashing, be sure to call `invalidateAndCancel` prior to removing an `MBXRasterTileOverlay` from an `MKMapView`.

    @warning Please note that you are responsible for getting permission to use the map data, and for ensuring your use adheres to the relevant terms of use.
    @warning Please note that to avoid crashes due to asynchronous completion handlers getting out of sync with MapKit's internal memory management, it is very important to call `invalidateAndCancel` before removing an `MBXRasterTileOverlay` from your `MKMapView`.
 */
@interface MBXRasterTileOverlay : MKTileOverlay


#pragma mark - Map tile overlay layer initialization and configuration

/** @name Map tile overlay layer initialization and configuration */

/** Initialize a map view with a given Mapbox map ID.
 *
 *   By default, `canReplaceMapContent` will be set to `YES`, which means Apple's maps will be hidden, and if the map ID represents a map with partial-world coverage, areas for which the map has no tiles will appear blank. If you have a full-world map with transparency and wish to show Apple's maps below it, set `canReplaceMapContent` to `NO` before adding your overlay to an `MKMapView`.
 *
 *   Also by default, asynchronous network requests will be started to load the metadata (center coordinate, zoom, etc) and markers associated with your map ID, if there are any. To receive notification when the asynchronous requests complete, set a delegate which implements `MBXRasterTileOverlayDelegate`.
 *
 *   In order for the tile overlay to appear on your map, your `MKMapView`'s delegate must implement `mapView:rendererForOverlay:` from the `MKMapViewDelegate` protocol. In order for markers to appear on your map, you must also provide an implementation for `mapView:viewForAnnotation:` which returns an `MKAnnotationView` initialized from an `MBXPointAnnotation`, including the image property.
 *
 *   @param mapID The Mapbox map ID.
 *   @return An initialized raster tile overlay, or `nil` if an overlay could not be initialized.
 */
- (id)initWithMapID:(NSString *)mapID;

/** Initialize a map view with a given Mapbox map ID while specifying whether to load metadata and markers.
 *   @param mapID The Mapbox map ID.
 *   @param includeMetadata Whether to load the map's metadata including center coordinate and zoom limits
 *   @param includeMarkers Whether to load the map's markers
 *   @return An initialized raster tile overlay, or `nil` if an overlay could not be initialized.
 */
- (id)initWithMapID:(NSString *)mapID includeMetadata:(BOOL)includeMetadata includeMarkers:(BOOL)includeMarkers;

/** Initialize a map view with a given Mapbox map ID while specifying whether to load metadata, whether to load markers, which image quality to request, and which user agent string to use.
 *   @param mapID The Mapbox map ID.
 *   @param includeMetadata Whether to load the map's metadata including center coordinate and zoom limits
 *   @param includeMarkers Whether to load the map's markers
 *   @param imageQuality The image quality to use for requesting tiles
 *   @param userAgent The user agent string to use for tile, metadata, and marker requests. Pass `nil` to use MBXMapKit's default user agent string.
 *   @return An initialized raster tile overlay, or `nil` if an overlay could not be initialized.
 */
- (id)initWithMapID:(NSString *)mapID includeMetadata:(BOOL)includeMetadata includeMarkers:(BOOL)includeMarkers imageQuality:(MBXRasterImageQuality)imageQuality userAgent:(NSString *)userAgent;

/** Initialize from an `MBXOfflineMapDatabase` object, using its stored values for metadata and markers, if it has any
 *   @param offlineMapDatabase An offline map database object obtained from `MBXOfflineMapDownloader`
 *   @return An initialized raster tile overlay, or `nil` if an overlay could not be initialized.
 */
- (id)initWithOfflineMapDatabase:(MBXOfflineMapDatabase *)offlineMapDatabase;


/** Delegate to notify about errors and asynchronously loaded resources */
@property (weak,nonatomic) id<MBXRasterTileOverlayDelegate> delegate;


/** Safely interrupt asynchronous completion handlers */
- (void)invalidateAndCancel;


#pragma mark - Read-only properties to check initialized values

/** @name Read-only properties for checking the initialized values */

/** The map ID this raster tile overlay was initialized with */
@property (readonly,nonatomic) NSString *mapID;
/** The map's center coordinate as parsed from the metadata JSON (see tileOverlay:didLoadMetadata:withError:) */
@property (readonly,nonatomic) CLLocationCoordinate2D center;
/** The map's initial zoom level as parsed from the metadata JSON (see tileOverlay:didLoadMetadata:withError:) */
@property (readonly,nonatomic) NSInteger centerZoom;
/** The map's array of MBXPointAnnotation marker annotations as parsed from the marker JSON (see tileOverlay:didLoadMarkers:withError:)*/
@property (readonly,nonatomic) NSArray *markers;
/** A default plain text attribution message suitable for displaying in an alert dialog (see metadata dictionary for an HTML string) */
@property (readonly,nonatomic) NSString *attribution;


#pragma mark - Methods for invalidating cached metadata and markers

/** @name Methods to clear resources from the HTTP performance cache */

/** Clear only the cached Metadata JSON (map center point, zoom limits, etc) */
- (void)clearCachedMetadata;

/** Clear only the cached Markers JSON */
- (void)clearCachedMarkers;


@end
