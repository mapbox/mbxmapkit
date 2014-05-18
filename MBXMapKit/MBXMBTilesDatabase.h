//
//  MBXMBTilesDatabase.h
//  MBXMapKit
//
//  Copyright (c) 2014 MapBox. All rights reserved.
//

@import Foundation;
@import MapKit;

@interface MBXMBTilesDatabase : NSObject

#pragma mark - Properties and methods for accessing stored map data

@property (readonly, nonatomic) NSString *name;
@property (readonly, nonatomic) NSString *type;
@property (readonly, nonatomic) NSString *version;
@property (readonly, nonatomic) NSString *description;
@property (readonly, nonatomic) NSString *format;
@property (readonly, nonatomic) MKCoordinateRegion mapRegion;
@property (readonly, nonatomic) NSInteger minimumZ;
@property (readonly, nonatomic) NSInteger maximumZ;
@property (readonly, nonatomic, getter=isInvalid) BOOL invalid;

@property (nonatomic) BOOL shouldOverzoom;

@end
