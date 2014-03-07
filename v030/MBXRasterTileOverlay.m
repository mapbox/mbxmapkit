//
//  MBXRasterTileOverlay.m
//  MBXMapKit
//
//  Created by Will Snook on 3/2/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXRasterTileOverlay.h"

@interface MBXRasterTileOverlay ()

@property (assign) MKMapRect mapRectForRegion;

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
    // Note: If you're wondering why this doesn't return a MapRect calculated from the TileJSON's bounds, it's been
    // tried and it doesn't work, possibly due to an MKMapKit bug. The main symptom is unpredictable visual glitching
    //
    return MKMapRectWorld;
}

- (void)setMapID:(NSString *)mapID
{
    _mapID = mapID;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){

        [_cacheManager prepareCacheForMapID:_mapID];

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
                if(!parseError
                   && tileJSONDictionary
                   && tileJSONDictionary[@"minzoom"]
                   && tileJSONDictionary[@"maxzoom"]
                   && tileJSONDictionary[@"center"] && [tileJSONDictionary[@"center"] count] == 3
                   && tileJSONDictionary[@"bounds"] && [tileJSONDictionary[@"bounds"] count] == 4
                   )
                {
                    // Setting these zoom limits helps to cut down on 404's for zoom levels that aren't part
                    // of the hosted map
                    //
                    self.minimumZ = [tileJSONDictionary[@"minzoom"] integerValue];
                    self.maximumZ = [tileJSONDictionary[@"maxzoom"] integerValue];

                    // Setting the center coordinate and zoom level allows view controllers to center the map
                    // on the hosted map's default view, as configured in the map editor.
                    //
                    _centerZoom = [tileJSONDictionary[@"center"][2] integerValue];
                    _center.latitude = [tileJSONDictionary[@"center"][1] doubleValue];
                    _center.longitude = [tileJSONDictionary[@"center"][0] doubleValue];


                    // Save the TileJSON, primarily for the purpose of triggering a KVO notification, which the
                    // mapView's view controller needs in order to know when center and centerZoom are available.
                    //
                    [self setTileJSONDictionary:tileJSONDictionary];
                    if (_delegate)
                    {
                        dispatch_async(dispatch_get_main_queue(), ^(void){
                            [_delegate MBXRasterTileOverlay:self didLoadMapID:_mapID];
                        });
                    }
                }
                else
                {
                    if ([_delegate respondsToSelector:@selector(MBXRasterTileOverlay:didFailToLoadMapID:withError:)]) {
                        [_delegate MBXRasterTileOverlay:self didFailToLoadMapID:_mapID withError:parseError];
                    }
                    else
                    {
                        NSLog(@"There was a problem parsing TileJSON for map ID %@ - (%@)",_mapID,parseError?parseError:@"");
                    }
                }
            }
            else
            {
                if ([_delegate respondsToSelector:@selector(MBXRasterTileOverlay:didFailToLoadMapID:withError:)]) {
                    [_delegate MBXRasterTileOverlay:self didFailToLoadMapID:_mapID withError:error];
                }
                else
                {
                    NSLog(@"There was a problem fetching TileJSON for map ID %@ - (%@)",_mapID,error?error:@"");
                }
            }
        }
    });
}

- (void)setTileJSONDictionary:(NSDictionary *)tileJSONDictionary
{
    _tileJSONDictionary = tileJSONDictionary;
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
