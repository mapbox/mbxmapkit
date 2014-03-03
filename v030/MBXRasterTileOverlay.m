//
//  MBXRasterTileOverlay.m
//  MBXMapKit
//
//  Created by Will Snook on 3/2/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXRasterTileOverlay.h"

@interface MBXRasterTileOverlay ()

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

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        NSError *error;
        NSData *data;
        data = [_cacheManager proxyTileJSONForMapID:_mapID withError:&error];

        // Someone might want to manually configure the zoom limits, center, etc, so check first before stomping
        // all over the existing configuration
        //
        if(!_inhibitTileJSON) {

            if (data && !error)
            {
                NSError *parseError;
                NSDictionary *tileJSONDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
                if(tileJSONDictionary && !parseError)
                {
                    if (tileJSONDictionary[@"minzoom"])
                    {
                        self.minimumZ = [tileJSONDictionary[@"minzoom"] integerValue];
                    }
                    if (tileJSONDictionary[@"maxzoom"])
                    {
                        self.maximumZ = [tileJSONDictionary[@"maxzoom"] integerValue];
                    }
                    if (tileJSONDictionary[@"center"])
                    {
                        self.centerZoom = [tileJSONDictionary[@"center"][2] integerValue];
                        self.center = CLLocationCoordinate2DMake([tileJSONDictionary[@"center"][1] doubleValue], [tileJSONDictionary[@"center"][0] doubleValue]);
                    }

                    [self setTileJSONDictionary:tileJSONDictionary];
                }
                else
                {
                    NSLog(@"There was a problem parsing TileJSON for map ID %@ - (%@)",_mapID,error?error:@"");
                }
            }
            else
            {
                NSLog(@"There was a problem fetching TileJSON for map ID %@ - (%@)",_mapID,error?error:@"");
            }
        }
    });
}

- (void)setTileJSONDictionary:(NSDictionary *)tileJSONDictionary
{
    // This is KVO compliant so that interested view controllers, tile overlay renderers, etc can
    // be notified when the tileJSON changes.
    //
    [self willChangeValueForKey:@"tileJSONDictionary"];
    _tileJSONDictionary = tileJSONDictionary;
    [self didChangeValueForKey:@"tileJSONDictionary"];
}


- (void)loadTileAtPath:(MKTileOverlayPath)path result:(void (^)(NSData *, NSError *))result
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        NSError *error;
        NSData *data;
        data = [_cacheManager proxyTileAtPath:path forMapID:_mapID withQuality:_imageQuality withError:&error];
        result(data,error);
    });
}

@end
