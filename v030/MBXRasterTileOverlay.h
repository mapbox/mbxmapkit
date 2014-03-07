//
//  MBXRasterTileOverlay.h
//  MBXMapKit
//
//  Created by Will Snook on 3/2/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import <MapKit/MapKit.h>
#import "MBXCacheManagerProtocol.h"
#import "MBXCacheManager.h"

@class MBXRasterTileOverlay;

@protocol MBXRasterTileOverlayDelegate <NSObject>

- (void)MBXRasterTileOverlay:(MBXRasterTileOverlay *)overlay didLoadMapID:(NSString *)mapID;

@optional

- (void)MBXRasterTileOverlay:(MBXRasterTileOverlay *)overlay didFailToLoadMapID:(NSString *)mapID withError:(NSError *)error;

@end


@interface MBXRasterTileOverlay : MKTileOverlay

@property (assign) MBXRasterImageQuality imageQuality;

@property (nonatomic) NSString *mapID;

// Note how gets set to a default in init, but after that it can be changed to
// anything that implements MBXCacheManagerProtocol
//
@property (nonatomic) id<MBXCacheManagerProtocol> cacheManager;

@property (assign) BOOL inhibitTileJSON;

@property (nonatomic) NSDictionary *tileJSONDictionary;

@property (assign) NSInteger centerZoom;
@property (assign) CLLocationCoordinate2D center;

@property (weak,nonatomic) id<MBXRasterTileOverlayDelegate> delegate;

@end
