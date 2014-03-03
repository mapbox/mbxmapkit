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
@property (nonatomic) NSData *TileJSON;

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

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void){
        self.tileJSON = [[MBXCacheManager sharedCacheManager] proxyTileJSONForMapID:_mapID withError:nil];
    });

}

- (void)loadTileAtPath:(MKTileOverlayPath)path result:(void (^)(NSData *, NSError *))result
{
    // Make the point that we're not blocking the main thread here
    //
    assert(![NSThread isMainThread]);
    
    NSError *error;
    NSData *data;
    data = [_cacheManager proxyTileAtPath:path forMapID:_mapID withQuality:_imageQuality withError:&error];


    /*

     NSError *parseError;

     NSDictionary *tileJSONDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];

     if (tileJSONDictionary)
     {
     for (NSString *requiredKey in @[ @"id", @"minzoom", @"maxzoom", @"bounds", @"center" ])
     {
     if ( ! tileJSONDictionary[requiredKey])
     {
     NSLog(@"Invalid TileJSON for map ID %@ (missing key '%@')", mapID, requiredKey);
     }
     }


     self.tileOverlay = [[MBXMapViewTileOverlay alloc] initWithTileJSONDictionary:tileJSONDictionary mapView:self];

     [[NSNotificationCenter defaultCenter] postNotificationName:[self notificationNameForTileJSON] object:self];

     }
     else
     {
     NSLog(@"Error parsing TileJSON for map ID %@ - retrying! (%@)", mapID, parseError);
     }

     */
    result(data,error);
}

@end
