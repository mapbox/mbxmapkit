//
//  MBXMBTilesOverlay.h
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

@import MapKit;

@class MBXMBTilesDatabase;

@interface MBXMBTilesOverlay : MKTileOverlay

- (instancetype)initWithMBTilesDatabase:(MBXMBTilesDatabase *)mbtileDatabase;

- (instancetype)init __attribute__((unavailable("To instantiate MBXMBTilesOverlay objects, please use initWithFileURL:.")));
- (instancetype)initWithURLTemplate:(NSString *)URLTemplate __attribute__((unavailable("To instantiate MBXMBTilesOverlay objects, please use initWithFileURL:.")));

#pragma mark - Read-only properties to check initialized values

@property (nonatomic) NSUInteger zoomLimit;
@property (nonatomic) BOOL shouldOverzoom;

@end
