//
//  MBXMBTilesDatabase.h
//  MBXMapKit
//
//  Copyright (c) 2014 MapBox. All rights reserved.
//

@import Foundation;
@import MapKit;

#pragma mark - Valid values for MBTiles spec parameters

// valid values for 'type'
extern NSString * const kTypeOverlay;
extern NSString * const kTypeBaselayer;

// valid values for 'format'
extern NSString * const kFormatJPEG;
extern NSString * const kFormatPNG;

@interface MBXMBTilesDatabase : NSObject

#pragma mark - Properties and methods for accessing stored map data

@property (readonly, nonatomic) NSString *name;
@property (readonly, nonatomic) NSString *type;
@property (readonly, nonatomic) NSString *version;
@property (readonly, nonatomic) NSString *description;
@property (readonly, nonatomic) NSString *format;
@property (readonly, nonatomic) MKMapRect mapRect;
@property (readonly, nonatomic) NSInteger minimumZ;
@property (readonly, nonatomic) NSInteger maximumZ;
@property (readonly, nonatomic, getter=isInvalid) BOOL invalid;

- (instancetype)initWithMBTilesURL:(NSURL *)mbtilesURL;

- (instancetype)init __attribute__((unavailable("To instantiate MBXMBTilesDatabase objects, please use initWithMBTilesURL:(NSURL *)mbtilesURL")));

@end
