//
//  MBXMapKit.m
//  MBXMapKit
//
//  Created by Justin R. Miller on 9/4/13.
//  Copyright (c) 2013-2014 Mapbox. All rights reserved.
//

#import "MBXMapKit.h"

#pragma mark Constants -

#define kMBXMapViewCacheFolder   @"MBXMapViewCache"
#define kMBXMapViewCacheInterval 60 * 60 * 24 * 7

NSString *const MBXMapKitErrorDomain = @"MBXMapKitErrorDomain";

NSInteger const MBXMapKitErrorCodeTileLoad = -1;

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

@end

#pragma mark -

@interface MBXMapViewDelegate : NSProxy <MKMapViewDelegate>

@property (nonatomic, weak) id <MKMapViewDelegate>realDelegate;

@end

#pragma mark -

@interface MBXMapView ()

@property (nonatomic) MBXMapViewShowDefaultBaseLayerMode showDefaultBaseLayerMode;
@property (nonatomic) MBXMapViewDelegate *ownedDelegate;
@property (nonatomic) NSURLSession *dataSession;
@property (nonatomic) NSURLSessionTask *metadataTask;
@property (nonatomic) NSURLSessionTask *markersTask;
@property (nonatomic) MBXMapViewTileOverlay *tileOverlay;
@property (nonatomic) BOOL hasInitialCenterCoordinate;
@property (nonatomic) NSString *cachePath;
@property (nonatomic) NSString *qualityExtension;

@end

#pragma mark -

@interface MBXSimpleStylePointAnnotation : MKShape

@end

#pragma mark - MBXSimpleStyleAnnotation - MKAnnotation delegate to model a simplestyle point -

@implementation MBXSimpleStylePointAnnotation

@synthesize coordinate = _coordinate;

- (CLLocationCoordinate2D)coordinate
{
    return _coordinate;
}

- (void)setCoordinate:(CLLocationCoordinate2D)coordinate
{
    [self willChangeValueForKey:@"coordinate"];
    _coordinate = coordinate;
    [self didChangeValueForKey:@"coordinate"];
}

@end

#pragma mark - MBXMapViewTileOverlay - Custom overlay fetching tiles from Mapbox -

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
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://%@.tiles.mapbox.com/v3/%@/%ld/%ld/%ld%@.%@",
                                    [@[ @"a", @"b", @"c", @"d" ] objectAtIndex:(rand() % 4)],
                                    self.mapView.mapID,
                                    (long)path.z,
                                    (long)path.x,
                                    (long)path.y,
                                    (path.contentScaleFactor > 1.0 ? @"@2x" : @""),
                                    self.mapView.qualityExtension]];
}

- (void)loadTileAtPath:(MKTileOverlayPath)path result:(void (^)(NSData *tileData, NSError *error))result
{
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
                if (error)
                {
                    // We got an NSURLSession-level error, so let's bail with it. This also covers airplane mode.
                    //
                    result(nil, error);
                }
                else if ([response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse *)response).statusCode != 200)
                {
                    // We don't want to cache or use non-images, so reject any HTTP-level errors.
                    //
                    NSString *errorReason = [NSString stringWithFormat:@"HTTP status %i was received", ((NSHTTPURLResponse *)response).statusCode];

                    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey        : NSLocalizedString(@"Tile load error", nil),
                                                NSLocalizedFailureReasonErrorKey : NSLocalizedString(errorReason, nil) };

                    result(nil, [NSError errorWithDomain:MBXMapKitErrorDomain code:MBXMapKitErrorCodeTileLoad userInfo:userInfo]);
                }
                else if ( ! [response isKindOfClass:[NSHTTPURLResponse class]])
                {
                    // We shouldn't be doing anything with non-HTTP responses.
                    //
                    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey        : NSLocalizedString(@"Tile load error", nil),
                                                NSLocalizedFailureReasonErrorKey : NSLocalizedString(@"The response received was not a valid HTTP response", nil) };

                    result(nil, [NSError errorWithDomain:MBXMapKitErrorDomain code:MBXMapKitErrorCodeTileLoad userInfo:userInfo]);
                }
                else
                {
                    // By this point, data is pretty likely to contain a valid image.
                    //
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
    return [NSString stringWithFormat:@"%@/%@/%ld_%ld_%ld%@.%@",
               [self.mapView cachePath],
               self.mapView.mapID,
               (long)path.z,
               (long)path.x,
               (long)path.y,
               (path.contentScaleFactor > 1.0 ? @"@2x" : @""),
               self.mapView.qualityExtension];
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

                if (attributes[NSFileType] == NSFileTypeRegular && [attributes[NSFileModificationDate] timeIntervalSinceDate:[NSDate date]] < -self.mapView.cacheInterval)
                    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
                else
                {
                    // Clean up any empty cache files that might be lying around from previous bugs
                    //
                    if ((attributes[NSFileType] == NSFileTypeRegular) && ([attributes[NSFileSize] integerValue] == 0))
                        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
                }
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

    if (selector == @selector(mapView:viewForAnnotation:))
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

    if (selector == @selector(mapView:viewForAnnotation:))
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

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MBXSimpleStylePointAnnotation class]])
    {
        static NSString *MBXSimpleStyleReuseIdentifier = @"MBXSimpleStyleReuseIdentifier";
        MKAnnotationView *view = [mapView dequeueReusableAnnotationViewWithIdentifier:MBXSimpleStyleReuseIdentifier];
        if (!view)
        {
            view = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:MBXSimpleStyleReuseIdentifier];
        }
        view.canShowCallout = YES;
        return view;
    }
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

    _imageQuality = MBXMapKitImageQualityFull;

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

- (void)setCamera:(MKMapCamera *)camera animated:(BOOL)animated
{
    self.hasInitialCenterCoordinate = YES;

    [super setCamera:camera animated:animated];
}

- (void)setCamera:(MKMapCamera *)camera
{
    self.hasInitialCenterCoordinate = YES;

    [super setCamera:camera];
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
        {
            [self updateOverlay];

            // The TileJSON from updateOverlay does include the path to the markers resource, but there's no need to wait around for
            // that to load since the marker resource location is known (see https://www.mapbox.com/developers/api/#Map.resources )
            //
            [self updateMarkers];
        }
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
                                            if (error)
                                            {
                                                NSLog(@"Attempting to load tileJSON produced an NSURLSession-level error - retrying! (%@)", error);
                                                [weakSelf updateOverlay];
                                            }
                                            else if ([response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse *)response).statusCode != 200)
                                            {
                                                NSLog(@"Attempting to load tileJSON failed by receiving an HTTP status %i - retrying!", ((NSHTTPURLResponse *)response).statusCode);
                                                [weakSelf updateOverlay];
                                            }
                                            else
                                            {
                                                // At this point we should have an NSHTTPURLResponse with an HTTP 200, or else an
                                                // NSURLResponse with the contents of a file from cache. Both of those are good.
                                                //
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
                                        }];

    [self.metadataTask resume];
}

- (void)addMarkersJSONDictionaryToMap:(NSDictionary *)markersJSONDictionary
{
    // Find point features in the markers dictionary (if there are any) and add them to the map.
    //
    id markers = markersJSONDictionary[@"features"];

    if (markers && [markers isKindOfClass:[NSArray class]])
    {
        id value;

        for (value in (NSArray *)markers)
        {
            if ([value isKindOfClass:[NSDictionary class]])
            {
                NSDictionary *feature = (NSDictionary *)value;
                NSString *type = feature[@"geometry"][@"type"];

                if ([@"Point" isEqualToString:type])
                {
                    // Only handle point features for now.
                    //
                    NSString *longitude   = feature[@"geometry"][@"coordinates"][0];
                    NSString *latitude    = feature[@"geometry"][@"coordinates"][1];
                    NSString *title       = feature[@"properties"][@"title"];
                    NSString *description = feature[@"properties"][@"description"];
                    NSString *size        = feature[@"properties"][@"marker-size"];
                    NSString *color       = feature[@"properties"][@"marker-color"];
                    NSString *symbol      = feature[@"properties"][@"marker-symbol"];

                    if (longitude && latitude && size && color && symbol)
                    {
                        title = (title ? title : @"");
                        description = (description ? description : @"");

                        MBXSimpleStylePointAnnotation *point = [MBXSimpleStylePointAnnotation new];

                        point.title      = title;
                        point.subtitle   = description;
                        point.coordinate = CLLocationCoordinate2DMake([latitude doubleValue], [longitude doubleValue]);

                        [self addAnnotation:point];
                    }
                    else
                    {
                        NSLog(@"This simplestyle Point feature is missing the %@ key", feature);
                    }
                }
            }
        }
    }
}

- (void)updateMarkers
{
    [self.markersTask cancel];

    [[NSFileManager defaultManager] createDirectoryAtPath:[NSString stringWithFormat:@"%@/%@", self.cachePath, self.mapID] withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *markersJSONCachePath = [NSString stringWithFormat:@"%@/%@/markers.geojson", self.cachePath, self.mapID];

    NSURL *markersJSONURL = ([[NSFileManager defaultManager] fileExistsAtPath:markersJSONCachePath] ? [NSURL fileURLWithPath:markersJSONCachePath] : [NSURL URLWithString:[NSString stringWithFormat:@"https://a.tiles.mapbox.com/v3/%@/markers.geojson", _mapID]]);

    __weak __typeof(self)weakSelf = self;

    self.markersTask = [self.dataSession dataTaskWithURL:markersJSONURL
                                       completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
                                       {
                                           if (error)
                                           {
                                               NSLog(@"Attempting to load simplestyle geoJSON produced an NSURLSession-level error, %@", error);
                                           }
                                           else if ([response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse *)response).statusCode != 200)
                                           {
                                               NSLog(@"Attempting to load simplestyle geoJSON failed by receiving an HTTP status %i", ((NSHTTPURLResponse *)response).statusCode);
                                           }
                                           else
                                           {
                                               // At this point we should have an NSHTTPURLResponse with an HTTP 200, or else an
                                               // NSURLResponse with the contents of a file from cache. Both of those are good.
                                               //
                                               NSError *parseError;
                                               NSDictionary *markersJSONDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];

                                               if (markersJSONDictionary)
                                               {
                                                   [data writeToFile:markersJSONCachePath atomically:YES];

                                                   dispatch_sync(dispatch_get_main_queue(), ^(void)
                                                   {
                                                       [weakSelf addMarkersJSONDictionaryToMap:markersJSONDictionary];
                                                   });
                                               }
                                               else
                                               {
                                                   NSLog(@"Error parsing simplestyle for map ID %@ (%@)", _mapID, parseError);
                                               }
                                           }
                                       }];

    [self.markersTask resume];
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


- (NSString *)qualityExtension
{
    NSString *qualityExtension;

    switch (self.imageQuality)
    {
        case MBXMapKitImageQualityPNG32:
            qualityExtension = @"png32";
            break;

        case MBXMapKitImageQualityPNG64:
            qualityExtension = @"png64";;
            break;

        case MBXMapKitImageQualityPNG128:
            qualityExtension = @"png128";
            break;

        case MBXMapKitImageQualityPNG256:
            qualityExtension = @"png256";
            break;

        case MBXMapKitImageQualityJPEG70:
            qualityExtension = @"jpg70";
            break;

        case MBXMapKitImageQualityJPEG80:
            qualityExtension = @"jpg80";
            break;

        case MBXMapKitImageQualityJPEG90:
            qualityExtension = @"jpg90";
            break;

        case MBXMapKitImageQualityFull:
        default:
            qualityExtension = @"png";
            break;
    }

    return qualityExtension;
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

- (void)emptyMarkerCacheForMapID:(NSString *)mapID
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(void)
    {
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@/markers.geojson", [self cachePath], mapID] error:nil];
    });
}

@end
