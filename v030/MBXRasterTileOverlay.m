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
    // This stuff doesn't work, possibly due to MKMapKit bugs. I'm leaving it here in case somebody wants to
    // uncomment it and experiment further with the not-working-ness
    /*
    if (_tileJSONDictionary && !_inhibitTileJSON)
    {
        return _mapRectForRegion;
    }
    else
    {
        return MKMapRectWorld;
    }
     */

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


                    // This stuff MapRect stuff doesn't work, possibly due to MKMapKit bugs. I'm leaving it here
                    // in case somebody wants to uncomment it and experiment further with the not-working-ness
                    //
                    /*
                    // Theoretically, converting the map bounds (latitude & longitude) to an MKMapRect (projected
                    // coordinates) allows -boundingMapRect to return something more specific than MKMapRectWorld,
                    // which should cut down on 404's for regional maps.
                    //
                    CLLocationCoordinate2D nw;
                    CLLocationCoordinate2D se;

                    nw.latitude = [tileJSONDictionary[@"bounds"][3] doubleValue];
                    nw.longitude = [tileJSONDictionary[@"bounds"][0] doubleValue];

                    se.latitude = [tileJSONDictionary[@"bounds"][1] doubleValue];
                    se.longitude = [tileJSONDictionary[@"bounds"][2] doubleValue];

                    MKMapPoint nwPoint = MKMapPointForCoordinate(nw);
                    MKMapPoint sePoint = MKMapPointForCoordinate(se);

                    MKMapSize size = MKMapSizeMake(sePoint.x - nwPoint.x, sePoint.y - nwPoint.y);
                    
                    _mapRectForRegion = MKMapRectMake(nwPoint.x, nwPoint.y, size.width, size.height);
                     */


                    // Save the TileJSON, primarily for the purpose of triggering a KVO notification, which the
                    // mapView's view controller needs in order to know when center and centerZoom are available.
                    //
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
