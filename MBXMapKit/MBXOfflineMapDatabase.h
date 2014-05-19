//
//  MBXOfflineMapDatabase.h
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

#import <MapKit/MapKit.h>
#import "MBXConstantsAndTypes.h"


#pragma mark -

/** A runtime object providing access to a database of persistent map data stored on disk. These objects are managed by MBXOfflineMapDownloader and are not meant to be directly instantiated by other means. */
@interface MBXOfflineMapDatabase : NSObject


#pragma mark - Properties and methods for accessing stored map data

/** @name Properties and methods for accessing stored map data */

/** The map ID from which the map resources in this offline map were downloaded */
@property (readonly, nonatomic) NSString *mapID;
/** Whether this offline map database includes the map's metadata JSON */
@property (readonly, nonatomic) BOOL includesMetadata;
/** Whether this offline map database includes the map's markers JSON and marker icons */
@property (readonly, nonatomic) BOOL includesMarkers;
/** The image quality used to download the tile URLs stored in this offline map database */
@property (readonly, nonatomic) MBXRasterImageQuality imageQuality;
/** The map region which was used to initiate the downloading of the tiles in this offline map database */
@property (readonly, nonatomic) MKCoordinateRegion mapRegion;
/** The minimum zoom limit which was used to initiate the downloading of the tiles in this offline map database */
@property (readonly, nonatomic) NSInteger minimumZ;
/** The maximum zoom limit which was used to initiate the downloading of the tiles in this offline map database */
@property (readonly, nonatomic) NSInteger maximumZ;
/** Whether this offline map database has been invalidated. This is to help prevent the completion handler in MBXRasterTileOverlay's  tileAtPath:result: from causing problems when overlay layers are removed from an MKMapView. */
@property (readonly, nonatomic, getter=isInvalid) BOOL invalid;

/** Mark this offline map object as no longer valid to prevent bad things from happening. This is designed to prevent bad things from happening with MBXRasterTileOverlay and MKMapView when MBXOfflineMapDownloader's removeOfflineMapDatabase: is invoked to remove an offline map's backing database from disk storage. */
- (void)invalidate;

/** Please use MBXOfflineMapDownloader to manage MBXOfflineMapDatabase objects. */
- (instancetype)init __attribute__((unavailable("To instantiate MBXOfflineMapDatabase objects, please use the capabilities provided by MBXOfflineMapDownloader.")));

@end
