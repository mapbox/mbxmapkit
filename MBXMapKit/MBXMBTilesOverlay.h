//
//  MBXMBTilesOverlay.h
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

@import MapKit;
#import "MBXConstantsAndTypes.h"

#pragma mark - Valid values for MBTiles spec parameters

// valid values for 'type'
extern NSString * const kTypeOverlay;
extern NSString * const kTypeBaselayer;

// valid values for 'format'
extern NSString * const kFormatJPEG;
extern NSString * const kFormatPNG;

@interface MBXMBTilesOverlay : MKTileOverlay

#pragma mark - Properties and methods for accessing stored map data

@property (readonly, nonatomic) NSURL      *mbtilesUrl;
@property (readonly, nonatomic) NSString   *name;
@property (readonly, nonatomic) NSString   *type;
@property (readonly, nonatomic) NSString   *version;
@property (readonly, nonatomic) NSString   *description;
@property (readonly, nonatomic) NSString   *format;
@property (readonly, nonatomic) MKMapRect  mapRect;
@property (nonatomic          ) NSUInteger zoomLimit;
@property (nonatomic          ) BOOL       shouldOverzoom;
@property (readonly, nonatomic, getter=isInvalid) BOOL invalid;

- (instancetype)initWithMBTilesURL:(NSURL *)mbtilesURL;

- (instancetype)init __attribute__((unavailable("To instantiate MBXMBTilesOverlay objects, please use initWithMBTilesURL:")));
- (instancetype)initWithURLTemplate:(NSString *)URLTemplate __attribute__((unavailable("To instantiate MBXMBTilesOverlay objects, please use initWithMBTilesURL:")));

@end
