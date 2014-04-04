//
//  MBXOfflineMapDatabase.h
//  MBXMapKit
//
//  Created by Will Snook on 3/17/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import "MBXRasterTileOverlay.h"


#pragma mark -

@interface MBXOfflineMapDatabase : NSObject


#pragma mark - Properties and methods for accessing stored map data

@property (readonly, nonatomic) NSString *mapID;
@property (readonly, nonatomic) BOOL metadata;
@property (readonly, nonatomic) BOOL markers;
@property (readonly, nonatomic) MBXRasterImageQuality imageQuality;
@property (readonly, nonatomic) MKCoordinateRegion mapRegion;
@property (readonly, nonatomic) NSInteger minimumZ;
@property (readonly, nonatomic) NSInteger maximumZ;

- (id)initWithContentsOfFile:(NSString *)path;

- (NSData *)dataForURL:(NSURL *)url withError:(NSError **)error;

@end
