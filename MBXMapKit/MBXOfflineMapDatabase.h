//
//  MBXOfflineMapDatabase.h
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

#import <MapKit/MapKit.h>
#import "MBXConstantsAndTypes.h"


#pragma mark -

@interface MBXOfflineMapDatabase : NSObject


#pragma mark - Properties and methods for accessing stored map data

@property (readonly, nonatomic) NSString *mapID;
@property (readonly, nonatomic) BOOL includesMetadata;
@property (readonly, nonatomic) BOOL includesMarkers;
@property (readonly, nonatomic) MBXRasterImageQuality imageQuality;
@property (readonly, nonatomic) MKCoordinateRegion mapRegion;
@property (readonly, nonatomic) NSInteger minimumZ;
@property (readonly, nonatomic) NSInteger maximumZ;
@property (readonly, nonatomic, getter=isInvalid) BOOL invalid;

- (void)invalidate;

// prevent init from being used
- (instancetype)init __attribute__((unavailable("To instantiate MBXOfflineMapDatabase objects, please use the cababilities provided by MBXOfflineMapDownloader.")));

@end
