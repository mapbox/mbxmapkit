//
//  MBXRasterTileOverlay.h
//  MBXMapKit
//
//  Created by Will Snook on 3/2/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import <MapKit/MapKit.h>
#import "MBXCacheManagerProtocol.h"

@interface MBXRasterTileOverlay : MKTileOverlay

@property (assign) MBXRasterImageQuality imageQuality;

@property (nonatomic) NSString *mapID;

@property (assign) BOOL inhibitTileJSON;

@property (nonatomic) NSInteger centerZoom;

@property (nonatomic) CLLocationCoordinate2D center;

@end
