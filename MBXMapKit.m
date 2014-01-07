//
//  MBXMapKit.m
//  MBXMapKit
//
//  Created by Justin R. Miller on 9/4/13.
//  Copyright (c) 2013 MapBox. All rights reserved.
//

#import "MBXMapKit.h"

#pragma mark Constants -

#define kMBXMapViewCacheFolder   @"MBXMapViewCache"
#define kMBXMapViewCacheInterval 60 * 60 * 24 * 7

typedef NS_ENUM(NSUInteger, MBXMapViewShowDefaultBaseLayerMode) {
    MBXMapViewShowDefaultBaseLayerNever,
    MBXMapViewShowDefaultBaseLayerAlways,
    MBXMapViewShowDefaultBaseLayerIfPartial,
};

#pragma mark - Private Interfaces -

@interface MBXMapViewTileOverlay : MKTileOverlay

@property (nonatomic, copy) NSDictionary *tileJSONDictionary;
@property (nonatomic, weak) MBXMapView *mapView;
@property (nonatomic) MKCoordinateRegion region;
#ifdef MBXMAPKIT_ENABLE_MBTILES_WITH_LIBSQLITE3
@property (nonatomic) NSString *mbtilesPath;
#endif

@end

#pragma mark -

@interface MBXMapViewDelegate : NSProxy <MKMapViewDelegate>

@property (nonatomic, weak) id <MKMapViewDelegate>realDelegate;

@end

#pragma mark -

@interface MBXMapView ()

- (NSString *)cachePath;

@property (nonatomic) MBXMapViewShowDefaultBaseLayerMode showDefaultBaseLayerMode;
@property (nonatomic) MBXMapViewDelegate *ownedDelegate;
@property (nonatomic) NSURLSession *dataSession;
@property (nonatomic) NSURLSessionTask *metadataTask;
@property (nonatomic) MBXMapViewTileOverlay *tileOverlay;
@property (nonatomic) BOOL hasInitialCenterCoordinate;

@end

#pragma mark - MBXMapViewTileOverlay - Custom overlay fetching tiles from MapBox -

@implementation MBXMapViewTileOverlay

@synthesize boundingMapRect=_boundingMapRect;

- (id)initWithTileJSONDictionary:(NSDictionary *)tileJSONDictionary mapView:(MBXMapView *)mapView
{
    self = [super initWithURLTemplate:nil];

    if (self)
    {
        _tileJSONDictionary = [tileJSONDictionary copy];

        if ( ! _tileJSONDictionary)
        {
            // Dummy layer requested. Never show default tiles.
            //
            _region = MKCoordinateRegionForMapRect(MKMapRectWorld);

            self.canReplaceMapContent = YES;
        }
        else
        {
            // Valid layer requested.
            //
            _mapView = mapView;
            
            self.minimumZ = [_tileJSONDictionary[@"minzoom"] integerValue];
            self.maximumZ = [_tileJSONDictionary[@"maxzoom"] integerValue];

            if (_mapView.showDefaultBaseLayerMode == MBXMapViewShowDefaultBaseLayerIfPartial)
            {
                // Show default tiles only if a partial overlay.
                //
                self.canReplaceMapContent = (self.region.span.latitudeDelta >= 170 && self.region.span.longitudeDelta == 360);
            }
            else if (_mapView.showDefaultBaseLayerMode == MBXMapViewShowDefaultBaseLayerNever)
            {
                // Don't show default tiles when told not to.
                //
                self.canReplaceMapContent = YES;
            }
            else
            {
                // Show default tiles per user request.
                //
                self.canReplaceMapContent = NO;
            }
        }
    }

    return self;
}

#ifdef MBXMAPKIT_ENABLE_MBTILES_WITH_LIBSQLITE3
- (id)initWithMBTilesPath:(NSString *)mbtilesPath mapView:(MBXMapView *)mapView
{
    self = [super initWithURLTemplate:nil];
    
    if (self)
    {
        _mapView = mapView;
        _tileJSONDictionary = nil;
        _mbtilesPath = mbtilesPath;

        // Read the metadata table to set min/max zoom and the map region
        NSString *minZoom = [self mbtilesMetadataValueForName:@"minzoom"];
        NSString *maxZoom = [self mbtilesMetadataValueForName:@"maxzoom"];
        NSString *bounds = [self mbtilesMetadataValueForName:@"bounds"];
        if (minZoom == nil || maxZoom == nil || bounds == nil)
        {
            // Oops, looks like we can't read from the MBTiles file, or else it's got a problem with the metadata table
            NSLog(@"initWithMBTilesPath:mapView: failed to read the MBTiles metadata.");
            return nil;
        }
        self.minimumZ = [minZoom integerValue];
        self.maximumZ = [maxZoom integerValue];
        
        // Parse the bounds string and convert it to a map region and boundingMapRect
        double west;
        double south;
        double east;
        double north;
        const char *cBounds = [bounds cStringUsingEncoding:NSASCIIStringEncoding];
        if (4 != sscanf(cBounds,"%lf,%lf,%lf,%lf",&west,&south,&east,&north))
        {
            // This is bad, bounds was supposed to have 4 comma-separated doubles
            NSLog(@"initWithMBTilesPath:mapView: failed to parse the map bounds: %@",bounds);
            return nil;
        }
        else
        {
            // Set the map region
            _region.center.latitude = (north + south) / 2.0;
            _region.center.longitude = (west + east) / 2.0;
            _region.span.latitudeDelta = north - south;
            _region.span.longitudeDelta = east - west;

            // Set the map bounds
            // FYI if anybody cares, the coordinate system for MKMapPoint works like this:
            // 85N,180W = (0,439674.4) ------> 85N,180E = (268435456.0, 439674.4)
            //  |
            //  |
            //  \/
            // 85S,180W = (0,267995781.6)
            // The origin is northwest, x increases as longitude moves west, and y increases as latitude moves south
            MKMapPoint nw = MKMapPointForCoordinate(CLLocationCoordinate2DMake(north, west));
            MKMapPoint se = MKMapPointForCoordinate(CLLocationCoordinate2DMake(south, east));
            _boundingMapRect.origin = nw;
            _boundingMapRect.size.width = se.x - nw.x;
            _boundingMapRect.size.height = se.y - nw.y;
        }
        
        // Determine whether or not to include the default tiles underneath this overlay
        if (_mapView.showDefaultBaseLayerMode == MBXMapViewShowDefaultBaseLayerIfPartial)
        {
            // Show default tiles only if a partial overlay.
            //
            self.canReplaceMapContent = (self.region.span.latitudeDelta >= 170 && self.region.span.longitudeDelta == 360);
        }
        else if (_mapView.showDefaultBaseLayerMode == MBXMapViewShowDefaultBaseLayerNever)
        {
            // Don't show default tiles when told not to.
            //
            self.canReplaceMapContent = YES;
        }
        else
        {
            // Show default tiles per user request.
            //
            self.canReplaceMapContent = NO;
        }
    }
    
    return self;
}

- (NSString *)mbtilesMetadataValueForName:(NSString *)name
{
    NSString *query = [NSString stringWithFormat:@"SELECT value FROM metadata WHERE name='%@';",name];
    NSData *data = [self mbtiles:_mbtilesPath dataForSingleColumnQuery:query];
    if (data == nil)
        return nil;
    else
        return [[NSString alloc] initWithBytes:data.bytes length:data.length encoding:NSUTF8StringEncoding];
}

- (NSData *)mbtiles:(NSString *)mbtilesPath dataForSingleColumnQuery:(NSString *)query
{
    // MBXMapKit expects libsqlite to have been compiled with SQLITE_THREADSAFE=2 (multi-thread mode), which means
    // that it can handle its own thread safety as long as you don't attempt to re-use database connections.
    // Considering how extensivly sqlite has been tested, relying on it to handle potential concurrency issues seems
    // like a desirable option. Also, it's worth noting that the queries for MBTiles stuff here are all SELECT's, so
    // locking for writes isn't an issue. Anyhow, the sqlite code here was written to be as simple as possible,
    // optimizing for safety and readability at the possible expense of performance.
    // Some relevant sqlite documentation:
    // - http://sqlite.org/faq.html#q5
    // - http://www.sqlite.org/threadsafe.html
    // - http://www.sqlite.org/c3ref/threadsafe.html
    // - http://www.sqlite.org/c3ref/c_config_covering_index_scan.html#sqliteconfigmultithread
    //
    assert(sqlite3_threadsafe()==2);
    
    // Open the database read-only and multi-threaded. The slightly obscure c-style variable names here and below are
    // used to stay consistent with the sqlite documentaion. See http://sqlite.org/c3ref/open.html
    sqlite3 *db;
    int rc;
    const char *filename = [mbtilesPath cStringUsingEncoding:NSUTF8StringEncoding];
    rc = sqlite3_open_v2(filename, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, NULL);
    if (rc)
    {
        NSLog(@"Can't open database: %s", sqlite3_errmsg(db));
        sqlite3_close(db);
        return nil;
    }
    
    // Prepare the query, see http://sqlite.org/c3ref/prepare.html
    const char *zSql = [query cStringUsingEncoding:NSUTF8StringEncoding];
    int nByte = [query lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    sqlite3_stmt *ppStmt;
    const char *pzTail;
    rc = sqlite3_prepare_v2(db, zSql, nByte, &ppStmt, &pzTail);
    if (rc)
    {
        NSLog(@"Problem preparing sql statement: %s", sqlite3_errmsg(db));
        sqlite3_finalize(ppStmt);
        sqlite3_close(db);
        return nil;
    }
    
    // Evaluate the query, see http://sqlite.org/c3ref/step.html and http://sqlite.org/c3ref/column_blob.html
    NSData *data = nil;
    rc = sqlite3_step(ppStmt);
    if (rc == SQLITE_ROW)
    {
        // The query is supposed to be for exactly one column
        assert(sqlite3_column_count(ppStmt)==1);
        
        // Success!
        data = [NSData dataWithBytes:sqlite3_column_blob(ppStmt, 0) length:sqlite3_column_bytes(ppStmt, 0)];
        
        // Check if any more rows match
        if(sqlite3_step(ppStmt) != SQLITE_DONE)
        {
            // Oops, the query apparently matched more than one row (could also be an error)... not fatal, but not good.
            NSLog(@"Warning, query may match more than one row: %@",query);
        }
    }
    else if (rc == SQLITE_DONE)
    {
        // The query returned no results. Depending on how the map is set up, this might indicate a problem, or it might
        // be okay. For instance, perhaps you want to set up a map with Apple's satellite map on the bottom and a couple
        // semi-transparent MBTiles overlays on top. Each of those three layers will potentially have different bounds,
        // min zoom, and max zoom. Setting MKTileOverlay's minimumZ and maximumZ properties for the MBTiles layers should
        // prevent calls to loadTileAtPath:result: for non-existant zoom levels, but you will probably still get calls for
        // tiles that are within the zoom limits but outside of the bounding box (TODO: test if that's really how it works).
        NSLog(@"Query returned no results: %@",query);
    }
    else if (rc == SQLITE_BUSY)
    {
        // This is bad, but theoretically it should never happen
        NSLog(@"sqlite3_step() returned SQLITE_BUSY. You probably have a concurrency problem.");
    }
    else
    {
        NSLog(@"sqlite3_step() isn't happy: %s", sqlite3_errmsg(db));
    }
    
    // Clean up
    sqlite3_finalize(ppStmt);
    sqlite3_close(db);
    return data;
}
#endif

- (NSInteger)centerZoom
{
    return [self.tileJSONDictionary[@"center"][2] integerValue];
}

- (MKCoordinateRegion)region
{
    if ( ! _region.span.latitudeDelta || ! _region.span.longitudeDelta)
    {
        CLLocationCoordinate2D center = CLLocationCoordinate2DMake([self.tileJSONDictionary[@"center"][1] doubleValue], [self.tileJSONDictionary[@"center"][0] doubleValue]);

        CLLocationCoordinate2D nw = CLLocationCoordinate2DMake([self.tileJSONDictionary[@"bounds"][3] doubleValue], [self.tileJSONDictionary[@"bounds"][0] doubleValue]);
        CLLocationCoordinate2D se = CLLocationCoordinate2DMake([self.tileJSONDictionary[@"bounds"][1] doubleValue], [self.tileJSONDictionary[@"bounds"][2] doubleValue]);

        MKCoordinateSpan span = MKCoordinateSpanMake((nw.latitude  - se.latitude), (se.longitude - nw.longitude));

        _region = MKCoordinateRegionMake(center, span);
    }

    return _region;
}

- (CLLocationCoordinate2D)coordinate
{
    return self.region.center;
}

- (MKMapRect)boundingMapRect
{
    if ( ! _boundingMapRect.size.width || ! _boundingMapRect.size.height)
    {
        CLLocationCoordinate2D nw = CLLocationCoordinate2DMake([self.tileJSONDictionary[@"bounds"][3] doubleValue], [self.tileJSONDictionary[@"bounds"][0] doubleValue]);
        CLLocationCoordinate2D se = CLLocationCoordinate2DMake([self.tileJSONDictionary[@"bounds"][1] doubleValue], [self.tileJSONDictionary[@"bounds"][2] doubleValue]);

        MKMapPoint nwPoint = MKMapPointForCoordinate(nw);
        MKMapPoint sePoint = MKMapPointForCoordinate(se);

        MKMapSize size = MKMapSizeMake(sePoint.x - nwPoint.x, sePoint.y - nwPoint.y);

        _boundingMapRect = MKMapRectMake(nwPoint.x, nwPoint.y, size.width, size.height);
    }

    return _boundingMapRect;
}

- (NSURL *)URLForTilePath:(MKTileOverlayPath)path
{
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://%@.tiles.mapbox.com/v3/%@/%ld/%ld/%ld%@.png",
                                    [@[ @"a", @"b", @"c", @"d" ] objectAtIndex:(rand() % 4)],
                                    self.mapView.mapID,
                                    (long)path.z,
                                    (long)path.x,
                                    (long)path.y,
                                    (path.contentScaleFactor > 1.0 ? @"@2x" : @"")]];
}

- (void)loadTileAtPath:(MKTileOverlayPath)path result:(void (^)(NSData *tileData, NSError *error))result
{
#ifdef MBXMAPKIT_ENABLE_MBTILES_WITH_LIBSQLITE3
    if (_mbtilesPath)
    {
        NSLog(@"mbtiles ltap:%ld,%ld,%ld",(long)path.x,(long)path.y,(long)path.z);
    }
#endif
    if ( ! self.mapView)
    {
        // Don't load any tiles if we are a dummy layer.
        //
        result(nil, nil);
    }
    else
    {
        NSData *cachedData;

        // Try the caching delegate first.
        //
        if ([self.mapView.cachingDelegate respondsToSelector:@selector(mapView:loadCacheDataForMapID:tilePath:)])
            cachedData = [self.mapView.cachingDelegate mapView:self.mapView loadCacheDataForMapID:self.mapView.mapID tilePath:path];

        // Then, check our own disk cache.
        //
        if ( ! cachedData)
            cachedData = [NSData dataWithContentsOfFile:[self cachePathForTilePath:path]];

        if (cachedData)
        {
            result(cachedData, nil);
        }
        else
        {
            // Otherwise, fetch & cache for next time.
            //
            [[self.mapView.dataSession dataTaskWithURL:[self URLForTilePath:path] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
            {
                if (data)
                {
                    // TODO: Possibly pay attention to HTTP response headers. Generally,
                    // though, we're going to assume that the dev knows what they want
                    // here given the possibility of no network access.

                    if ([self.mapView.cachingDelegate respondsToSelector:@selector(mapView:saveCacheData:forMapID:tilePath:)])
                    {
                        // Offer to the caching delegate first.
                        //
                        [self.mapView.cachingDelegate mapView:self.mapView saveCacheData:data forMapID:self.mapView.mapID tilePath:path];
                    }
                    else
                    {
                        // Cache to disk in folders sorted by mapID.
                        //
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(void)
                        {
                            [data writeToFile:[self cachePathForTilePath:path] atomically:YES];
                        });
                    }

                    // Return the new tile data.
                    //
                    result(data, nil);
                }
                else
                {
                    // Return the fetch error directly.
                    //
                    result(nil, error);
                }
            }] resume];
        }

        // sweep cache periodically
        //
        if (rand() % 1000 == 0)
        {
            [self sweepCache];
        }
    }
}

- (NSString *)cachePathForTilePath:(MKTileOverlayPath)path
{
    return [NSString stringWithFormat:@"%@/%@/%ld_%ld_%ld%@.png",
               [self.mapView cachePath],
               self.mapView.mapID,
               (long)path.z,
               (long)path.x,
               (long)path.y,
               (path.contentScaleFactor > 1.0 ? @"@2x" : @"")];
}

- (void)sweepCache
{
    if (self.mapView)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(void)
        {
            NSDirectoryEnumerator *cacheEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:[self.mapView cachePath]];
            NSString *filename;

            while ((filename = [cacheEnumerator nextObject]))
            {
                NSString *filePath = [NSString stringWithFormat:@"%@/%@", [self.mapView cachePath], filename];
                NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];

                if (attributes[NSFileType] == NSFileTypeRegular && [attributes[NSFileModificationDate] timeIntervalSinceDate:[NSDate date]] < -kMBXMapViewCacheInterval)
                    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
            }
        });
    }
}

@end

#pragma mark - MBXMapViewDelegate - Proxying delegate that ensures tile renderer -

@implementation MBXMapViewDelegate

+ (id)new
{
    return [[self alloc] init];
}

- (id)init
{
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MBXMapViewDelegate: %p, realDelegate (%@): %p>", self, (self.realDelegate ? [self.realDelegate class] : @""), self.realDelegate];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
    if (selector == @selector(mapView:rendererForOverlay:))
        return [[MBXMapViewDelegate class] methodSignatureForSelector:selector];

    if ([self.realDelegate respondsToSelector:selector])
        return [(NSObject *)self.realDelegate methodSignatureForSelector:selector];

    return [[NSObject class] methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    if (invocation.selector == @selector(respondsToSelector:))
    {
        [invocation invokeWithTarget:self];
    }
    else if ([self.realDelegate respondsToSelector:invocation.selector])
    {
        [invocation invokeWithTarget:self.realDelegate];
    }
}

- (BOOL)respondsToSelector:(SEL)selector
{
    if (selector == @selector(mapView:rendererForOverlay:))
        return YES;

    return ([self.realDelegate respondsToSelector:selector]);
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id <MKOverlay>)overlay
{
    if ([self.realDelegate respondsToSelector:@selector(mapView:rendererForOverlay:)])
    {
        // If user-set delegate wants to provide a tile renderer, let it.
        //
        if ([overlay isKindOfClass:[MBXMapViewTileOverlay class]])
        {
            // If it fails at providing a renderer for our managed overlay, step in.
            //
            MKOverlayRenderer *renderer = [self.realDelegate mapView:mapView rendererForOverlay:overlay];

            return (renderer ? renderer : [[MKTileOverlayRenderer alloc] initWithTileOverlay:overlay]);
        }
        else
        {
            // Let it provide a renderer for all user-set overlays.
            //
            return [self.realDelegate mapView:mapView rendererForOverlay:overlay];
        }
    }
    else if ([overlay isKindOfClass:[MBXMapViewTileOverlay class]])
    {
        // Step in if the user-set delegate doesn't try to provide a renderer.
        //
        return [[MKTileOverlayRenderer alloc] initWithTileOverlay:overlay];
    }

    // We're not in the general renderer-providing business.
    //
    return nil;
}

@end

#pragma mark - MBXMapView - Map view with self-managing overlay & proxying delegate -

@implementation MBXMapView

- (void)MBXMapView_commonSetupWithMapID:(NSString *)mapID showDefaultBaseLayerMode:(MBXMapViewShowDefaultBaseLayerMode)mode
{
    id existingDelegate;

    if (self.delegate)
        existingDelegate = self.delegate; // XIB

    _ownedDelegate = [MBXMapViewDelegate new];
    [super setDelegate:_ownedDelegate];

    _ownedDelegate.realDelegate = existingDelegate;

    NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    sessionConfiguration.HTTPAdditionalHeaders = @{ @"User-Agent" : [self userAgentString] };
    _dataSession = [NSURLSession sessionWithConfiguration:sessionConfiguration];

    _cacheInterval = kMBXMapViewCacheInterval;

    _showDefaultBaseLayerMode = mode;

    if (_showDefaultBaseLayerMode == MBXMapViewShowDefaultBaseLayerNever || _showDefaultBaseLayerMode == MBXMapViewShowDefaultBaseLayerIfPartial)
    {
        // Add dummy overlay until we get TileJSON. Don't show default tiles just in case.
        //
        self.tileOverlay = [[MBXMapViewTileOverlay alloc] initWithTileJSONDictionary:nil mapView:self];
        [self insertOverlay:self.tileOverlay atIndex:0];
    }

    [self setMapID:mapID];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];

    if (self)
        [self MBXMapView_commonSetupWithMapID:nil showDefaultBaseLayerMode:MBXMapViewShowDefaultBaseLayerAlways];

    return self;
}

- (id)initWithFrame:(CGRect)frame mapID:(NSString *)mapID
{
    self = [super initWithFrame:frame];

    if (self)
        [self MBXMapView_commonSetupWithMapID:mapID showDefaultBaseLayerMode:MBXMapViewShowDefaultBaseLayerIfPartial];

    return self;
}

- (id)initWithFrame:(CGRect)frame mapID:(NSString *)mapID showDefaultBaseLayer:(BOOL)showDefaultBaseLayer
{
    self = [super initWithFrame:frame];

    if (self)
        [self MBXMapView_commonSetupWithMapID:mapID showDefaultBaseLayerMode:(showDefaultBaseLayer ? MBXMapViewShowDefaultBaseLayerAlways : MBXMapViewShowDefaultBaseLayerNever)];

    return self;
}

#ifdef MBXMAPKIT_ENABLE_MBTILES_WITH_LIBSQLITE3
- (id)initWithFrame:(CGRect)frame mbtilesPath:(NSString *)mbtilesPath
{
    return [self initWithFrame:frame mbtilesPath:mbtilesPath showDefaultBaseLayer:NO];
}

- (id)initWithFrame:(CGRect)frame mbtilesPath:(NSString *)mbtilesPath showDefaultBaseLayer:(BOOL)showDefaultBaseLayer
{
    self = [super initWithFrame:frame];
    
    if (self) {
        // This stuff is adapted from MBXMapView_commonSetupWithMapID:showDefaultBaseLayerMode:
        id existingDelegate;
        if (self.delegate)
            existingDelegate = self.delegate; // XIB
        _ownedDelegate = [MBXMapViewDelegate new];
        [super setDelegate:_ownedDelegate];
        _ownedDelegate.realDelegate = existingDelegate;
        _dataSession = nil;
        _cacheInterval = kMBXMapViewCacheInterval;
        _showDefaultBaseLayerMode = (showDefaultBaseLayer ? MBXMapViewShowDefaultBaseLayerAlways : MBXMapViewShowDefaultBaseLayerNever);
        
        // And this is for the mbtiles overlay (which doesn't have any TileJSON async loading issues)
        self.tileOverlay = [[MBXMapViewTileOverlay alloc] initWithMBTilesPath:mbtilesPath mapView:self];
        [self insertOverlay:self.tileOverlay atIndex:0];
    }
    
    return self;
}
#endif

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super initWithCoder:decoder];

    if (self)
        [self MBXMapView_commonSetupWithMapID:nil showDefaultBaseLayerMode:MBXMapViewShowDefaultBaseLayerNever];

    return self;
}

- (void)setCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate
{
    self.hasInitialCenterCoordinate = YES;

    [super setCenterCoordinate:centerCoordinate];
}

- (void)setRegion:(MKCoordinateRegion)region
{
    self.hasInitialCenterCoordinate = YES;

    [super setRegion:region];
}

- (void)setVisibleMapRect:(MKMapRect)visibleMapRect
{
    self.hasInitialCenterCoordinate = YES;

    [super setVisibleMapRect:visibleMapRect];
}

- (void)setCenterCoordinate:(CLLocationCoordinate2D)coordinate animated:(BOOL)animated
{
    self.hasInitialCenterCoordinate = YES;

    [super setCenterCoordinate:coordinate animated:animated];
}

- (void)setRegion:(MKCoordinateRegion)region animated:(BOOL)animated
{
    self.hasInitialCenterCoordinate = YES;

    [super setRegion:region animated:animated];
}

- (void)setVisibleMapRect:(MKMapRect)mapRect animated:(BOOL)animate
{
    self.hasInitialCenterCoordinate = YES;

    [super setVisibleMapRect:mapRect animated:animate];
}

#if TARGET_OS_IPHONE
- (void)setVisibleMapRect:(MKMapRect)mapRect edgePadding:(UIEdgeInsets)insets animated:(BOOL)animate
#else
- (void)setVisibleMapRect:(MKMapRect)mapRect edgePadding:(NSEdgeInsets)insets animated:(BOOL)animate
#endif
{
    self.hasInitialCenterCoordinate = YES;

    [super setVisibleMapRect:mapRect edgePadding:insets animated:animate];
}

- (void)showAnnotations:(NSArray *)annotations animated:(BOOL)animated
{
    self.hasInitialCenterCoordinate = YES;

    [super showAnnotations:annotations animated:animated];
}

- (void)setCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate zoomLevel:(NSUInteger)zoomLevel animated:(BOOL)animated
{
    [self setRegion:MKCoordinateRegionMake(centerCoordinate, MKCoordinateSpanMake(0, 360 / pow(2, zoomLevel) * self.frame.size.width / 256)) animated:animated];
}

- (void)setMapID:(NSString *)mapID
{
    if ( ! [_mapID isEqual:mapID])
    {
        _mapID = [mapID copy];

        if (_mapID)
            [self updateOverlay];
    }
}

- (void)updateOverlay
{
    [self.metadataTask cancel];

    [[NSFileManager defaultManager] createDirectoryAtPath:[NSString stringWithFormat:@"%@/%@", self.cachePath, self.mapID]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

    NSString *tileJSONCachePath = [NSString stringWithFormat:@"%@/%@/%@.json", self.cachePath, self.mapID, self.mapID];

    NSURL *tileJSONURL = ([[NSFileManager defaultManager] fileExistsAtPath:tileJSONCachePath] ? [NSURL fileURLWithPath:tileJSONCachePath] : [NSURL URLWithString:[NSString stringWithFormat:@"https://a.tiles.mapbox.com/v3/%@.json", _mapID]]);

    __weak __typeof(self)weakSelf = self;

    self.metadataTask = [self.dataSession dataTaskWithURL:tileJSONURL
                                        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
                                        {
                                            if (data)
                                            {
                                                NSError *parseError;

                                                NSDictionary *tileJSONDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];

                                                if (tileJSONDictionary)
                                                {
                                                    for (NSString *requiredKey in @[ @"id", @"minzoom", @"maxzoom", @"bounds", @"center" ])
                                                    {
                                                        if ( ! tileJSONDictionary[requiredKey])
                                                        {
                                                            NSLog(@"Invalid TileJSON for map ID %@ - retrying! (missing key '%@')", _mapID, requiredKey);

                                                            return [weakSelf updateOverlay];
                                                        }
                                                    }

                                                    [data writeToFile:tileJSONCachePath atomically:YES];

                                                    dispatch_sync(dispatch_get_main_queue(), ^(void)
                                                    {
                                                        // Remove existing overlay.
                                                        //
                                                        [self removeOverlay:self.tileOverlay];

                                                        // Add the real overlay. Obey the original default tiles request mode.
                                                        //
                                                        self.tileOverlay = [[MBXMapViewTileOverlay alloc] initWithTileJSONDictionary:tileJSONDictionary mapView:self];

                                                        [self.tileOverlay sweepCache];

                                                        [self insertOverlay:self.tileOverlay atIndex:0];

                                                        if ( ! self.hasInitialCenterCoordinate)
                                                            [self setCenterCoordinate:self.tileOverlay.coordinate zoomLevel:self.tileOverlay.centerZoom animated:NO];
                                                    });
                                                }
                                                else
                                                {
                                                    NSLog(@"Error parsing TileJSON for map ID %@ - retrying! (%@)", _mapID, parseError);

                                                    [weakSelf updateOverlay];
                                                }
                                            }
                                            else
                                            {
                                                NSLog(@"Error downloading TileJSON for map ID %@ - retrying! (%@)", _mapID, error);

                                                [weakSelf updateOverlay];
                                            }
                                        }];

    [self.metadataTask resume];
}

- (void)reloadRenderer
{
    if ([self rendererForOverlay:self.tileOverlay])
    {
        NSInteger index = [self.overlays indexOfObject:self.tileOverlay];
        [self removeOverlay:self.tileOverlay];
        [self insertOverlay:self.tileOverlay atIndex:index];
    }
}

- (void)setDelegate:(id<MKMapViewDelegate>)delegate
{
    // MKMapView scans its delegate for implemented methods when set. Here we set the same
    // delegate again to cause a re-scan of possible new methods in the user-set delegate.
    // We also reload the managed overlay to give the new delegate a chance to supply its
    // own tile renderer.
    //
    [super setDelegate:nil];
    self.ownedDelegate.realDelegate = delegate;
    [super setDelegate:self.ownedDelegate];
    [self reloadRenderer];
}

- (NSString *)userAgentString
{
#if TARGET_OS_IPHONE
    return [NSString stringWithFormat:@"MBXMapKit (%@/%@)", [[UIDevice currentDevice] model], [[UIDevice currentDevice] systemVersion]];
#else
    return [NSString stringWithFormat:@"MBXMapKit (OS X/%@)", [[NSProcessInfo processInfo] operatingSystemVersionString]];
#endif
}

- (NSString *)systemPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);

    NSString *path = ([paths count] ? paths[0] : NSTemporaryDirectory());

#if ! TARGET_OS_IPHONE
    path = [NSString stringWithFormat:@"%@/%@", path, [[NSProcessInfo processInfo] processName]];
#endif

    return path;
}

- (NSString *)cachePath
{
    static NSString *_cachePath;

    if ( ! _cachePath)
        _cachePath = [NSString stringWithFormat:@"%@/%@", [self systemPath], kMBXMapViewCacheFolder];

    return _cachePath;
}

- (void)setCacheInterval:(NSTimeInterval)cacheInterval
{
    _cacheInterval = cacheInterval;

    [self.tileOverlay sweepCache];
}

- (void)emptyCacheForMapID:(NSString *)mapID
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(void)
    {
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", [self cachePath], mapID] error:nil];
    });
}

@end