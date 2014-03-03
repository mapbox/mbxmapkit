//
//  MBXRasterTileOverlay.m
//  MBXMapKit
//
//  Created by Will Snook on 3/2/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXRasterTileOverlay.h"
#import "MBXCacheManager.h"

@interface MBXRasterTileOverlay ()

@property (nonatomic) MBXCacheManager *cacheManager;

@end

@implementation MBXRasterTileOverlay

- (id)init
{
    self = [super init];
    if (self)
    {
        self.canReplaceMapContent = YES;
        _cacheManager = [MBXCacheManager sharedCacheManager];
    }
    return self;
}

- (MKMapRect)boundingMapRect
{
    return MKMapRectWorld;
}

- (void)setMapID:(NSString *)mapID
{
    _mapID = mapID;
}

- (void)loadTileAtPath:(MKTileOverlayPath)path result:(void (^)(NSData *, NSError *))result
{
    // Make the point that we're not blocking the main thread here
    //
    assert(![NSThread isMainThread]);
    
    NSError *error;
    NSData *data;
    data = [_cacheManager proxyTileAtPath:path forMapID:_mapID withError:&error];
    result(data,error);
}

@end
