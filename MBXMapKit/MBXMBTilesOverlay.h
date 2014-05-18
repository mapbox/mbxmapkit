//
//  MBXMBTilesOverlay.h
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

@import MapKit;

@class MBXMBTilesDatabase;

@interface MBXMBTilesOverlay : MKTileOverlay

- (instancetype)initWithMBXMBTilesDatabase:(MBXMBTilesDatabase *)mbtileDatabase;
- (instancetype)init __attribute__((unavailable("To instantiate MBXMBTilesOverlay objects, please use initWithFileURL:.")));
- (instancetype)initWithURLTemplate:(NSString *)URLTemplate __attribute__((unavailable("To instantiate MBXMBTilesOverlay objects, please use initWithFileURL:.")));

#pragma mark - Read-only properties to check initialized values

/** @name Read-only properties for checking the initialized values */
@property (readonly,nonatomic) NSString *mapID;
@property (readonly,nonatomic) CLLocationCoordinate2D center;
@property (readonly,nonatomic) NSInteger centerZoom;
@property (readonly,nonatomic) NSArray *markers;
@property (readonly,nonatomic) NSString *attribution;

@end
