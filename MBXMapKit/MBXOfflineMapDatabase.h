//
//  MBXOfflineMapDatabase.h
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

@import Foundation;
@import MapKit;

#import "MBXConstantsAndTypes.h"

#pragma mark -

/** An instance of the `MBXOfflineMapDatabase` class represents a store of offline map data, including map tiles, JSON metadata, and marker images.
*
*   @warning The `MBXOfflineMapDatabase` class is not meant to be instantiated directly. Instead, instances are created and managed by the shared `MBXOfflineMapDownloader` instance. */
@interface MBXOfflineMapDatabase : NSObject


#pragma mark - Properties and methods for accessing stored map data

/** @name Getting and Setting Properties */

/** A unique identifier for the offline map database. */
@property (readonly, nonatomic) NSString *uniqueID;

/** The Mapbox map ID from which the map resources in this offline map were downloaded. */
@property (readonly, nonatomic) NSString *mapID;

/** Whether this offline map database includes the map's metadata JSON. */
@property (readonly, nonatomic) BOOL includesMetadata;

/** Whether this offline map database includes the map's markers JSON and marker icons. */
@property (readonly, nonatomic) BOOL includesMarkers;

/** The image quality used to download the raster tile images stored in this offline map database. */
@property (readonly, nonatomic) MBXRasterImageQuality imageQuality;

/** The map region which was used to initiate the downloading of the tiles in this offline map database. */
@property (readonly, nonatomic) MKCoordinateRegion mapRegion;

/** The minimum zoom limit which was used to initiate the downloading of the tiles in this offline map database. */
@property (readonly, nonatomic) NSInteger minimumZ;

/** The maximum zoom limit which was used to initiate the downloading of the tiles in this offline map database. */
@property (readonly, nonatomic) NSInteger maximumZ;

/** Whether this offline map database has been invalidated. This is to help prevent the completion handlers in `MBXRasterTileOverlay` from causing problems after overlay layers are removed from an `MKMapView`. */
@property (readonly, nonatomic, getter=isInvalid) BOOL invalid;

/** Initial creation date of the offline map database. */
@property (readonly, nonatomic) NSDate *creationDate;

- (instancetype)init UNAVAILABLE_ATTRIBUTE;

@end
