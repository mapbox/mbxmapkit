//
//  MBXRasterTileOverlay.m
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

#import "MBXMapKit.h"

typedef NS_ENUM(NSUInteger, MBXRenderCompletionState) {
    MBXRenderCompletionStateUnknown = 0,
    MBXRenderCompletionStatePartial = 1,
    MBXRenderCompletionStateFull = 2
};

typedef void (^MBXRasterTileOverlayWorkerBlock)(NSData *data, NSError **error);
typedef void (^MBXRasterTileOverlayCompletionBlock)(NSData *data, NSError *error);

#pragma mark - Private API for creating verbose errors

@interface NSError (MBXError)

+ (NSError *)mbx_errorWithCode:(NSInteger)code reason:(NSString *)reason description:(NSString *)description;

+ (NSError *)mbx_errorCannotOpenOfflineMapDatabase:(NSString *)path sqliteError:(const char *)sqliteError;

+ (NSError *)mbx_errorQueryFailedForOfflineMapDatabase:(NSString *)path sqliteError:(const char *)sqliteError;

@end


#pragma mark - Private API for cooperating with MBXOfflineMapDatabase

@interface MBXOfflineMapDatabase ()

- (NSData *)dataForURL:(NSURL *)url withError:(NSError **)error;

@end


#pragma mark -

@interface MBXRasterTileOverlay ()


#pragma mark - Private read-write backing properties for public read-only properties

@property (readwrite,nonatomic) NSString *mapID;
@property (readwrite,nonatomic) MBXRasterImageQuality imageQuality;
@property (readwrite,nonatomic) CLLocationCoordinate2D center;
@property (readwrite,nonatomic) NSInteger centerZoom;
@property (readwrite,nonatomic) NSArray *markers;
@property (readwrite,nonatomic) NSString *attribution;

#pragma mark - Private properties for rendering completion notification

@property (nonatomic) NSMutableSet *pendingTileRenders;
@property (nonatomic) MBXRenderCompletionState renderCompletionState;

#pragma mark - Properties for asynchronous downloading of metadata and markers

@property (nonatomic) NSDictionary *tileJSONDictionary;
@property (nonatomic) NSDictionary *simplestyleJSONDictionary;
@property (nonatomic) BOOL sessionHasBeenInvalidated;
@property (nonatomic) NSURL *metadataURL;
@property (nonatomic) NSURL *markersURL;
@property (nonatomic) NSMutableArray *mutableMarkers;
@property (nonatomic) NSInteger activeMarkerIconRequests;
@property (nonatomic) BOOL markerIconLoaderMayInitiateDelegateCallback;
@property (nonatomic) BOOL didFinishLoadingMetadata;
@property (nonatomic) BOOL didFinishLoadingMarkers;

@property (strong, nonatomic) MBXOfflineMapDatabase *offlineMapDatabase;

@property (nonatomic) NSDictionary *metadataForPendingNotification;
@property (nonatomic) NSError *metadataErrorForPendingNotification;
@property (nonatomic) NSArray *markersForPendingNotification;
@property (nonatomic) NSError *markersErrorForPendingNotification;
@property (nonatomic) BOOL needToNotifyDelegateThatMetadataAndMarkersAreFinished;

@end


#pragma mark - MBXRasterTileOverlay, a subclass of MKTileOverlay

@implementation MBXRasterTileOverlay


#pragma mark - URL utility funtions

+ (NSString *)qualityExtensionForImageQuality:(MBXRasterImageQuality)imageQuality
{
    NSString *qualityExtension;
    switch (imageQuality)
    {
        case MBXRasterImageQualityPNG32:
            qualityExtension = @"png32";
            break;
        case MBXRasterImageQualityPNG64:
            qualityExtension = @"png64";;
            break;
        case MBXRasterImageQualityPNG128:
            qualityExtension = @"png128";
            break;
        case MBXRasterImageQualityPNG256:
            qualityExtension = @"png256";
            break;
        case MBXRasterImageQualityJPEG70:
            qualityExtension = @"jpg70";
            break;
        case MBXRasterImageQualityJPEG80:
            qualityExtension = @"jpg80";
            break;
        case MBXRasterImageQualityJPEG90:
            qualityExtension = @"jpg90";
            break;
        case MBXRasterImageQualityFull:
        default:
            qualityExtension = @"png";
            break;
    }
    return qualityExtension;
}

+ (NSURLCache *)overlayURLCache
{
    return [NSURLCache sharedURLCache];
}

+ (NSURLRequest *)overlayURLRequestForURL:(NSURL *)requestURL
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL];
    request.cachePolicy = NSURLRequestUseProtocolCachePolicy;
    request.timeoutInterval = 60;
    request.allowsCellularAccess = YES;
    [request addValue:[MBXMapKit userAgent] forHTTPHeaderField:@"User-Agent"];

    return request;
}

+ (NSURL *)markerIconURLForSize:(NSString *)size symbol:(NSString *)symbol color:(NSString *)color
{
    // Make a string which follows the MapBox Core API spec for stand-alone markers. This relies on the MapBox API
    // for error checking.
    //
    NSMutableString *marker = [[NSMutableString alloc] initWithString:@"pin-"];

    if ([size hasPrefix:@"l"])
    {
        [marker appendString:@"l"]; // large
    }
    else if ([size hasPrefix:@"s"])
    {
        [marker appendString:@"s"]; // small
    }
    else
    {
        [marker appendString:@"m"]; // default to medium
    }

    if ([symbol length] > 0)
    {
        [marker appendFormat:@"-%@+",symbol];
    }
    else
    {
        [marker appendString:@"+"];
    }

    [marker appendString:[color stringByReplacingOccurrencesOfString:@"#" withString:@""]];

#if TARGET_OS_IPHONE
    [marker appendString:([[UIScreen mainScreen] scale] > 1.0 ? @"@2x.png" : @".png")];
#else
    // Making this smart enough to handle a Retina MacBook with a normal dpi external display is complicated.
    // For now, just default to @1x images and a 1.0 scale.
    //
    [marker appendString:@".png"];
#endif

    return [NSURL URLWithString:[NSString stringWithFormat:@"https://a.tiles.mapbox.com/v4/marker/%@%@", marker,
                                    [@"?access_token=" stringByAppendingString:[MBXMapKit accessToken]]]];
}


#pragma mark - Initialization

- (instancetype)initWithMapID:(NSString *)mapID;
{
    self = [super init];
    if (self)
    {
        [self setupMapID:mapID includeMetadata:YES includeMarkers:YES imageQuality:MBXRasterImageQualityFull];
    }
    return self;
}


- (instancetype)initWithMapID:(NSString *)mapID includeMetadata:(BOOL)includeMetadata includeMarkers:(BOOL)includeMarkers
{
    self = [super init];
    if (self)
    {
        [self setupMapID:mapID includeMetadata:includeMetadata includeMarkers:includeMarkers imageQuality:MBXRasterImageQualityFull];
    }
    return self;
}


- (instancetype)initWithMapID:(NSString *)mapID includeMetadata:(BOOL)includeMetadata includeMarkers:(BOOL)includeMarkers imageQuality:(MBXRasterImageQuality)imageQuality
{
    self = [super init];
    if (self)
    {
        [self setupMapID:mapID includeMetadata:includeMetadata includeMarkers:includeMarkers imageQuality:imageQuality];
    }
    return self;
}

- (instancetype)initWithOfflineMapDatabase:(MBXOfflineMapDatabase *)offlineMapDatabase
{
    assert(offlineMapDatabase);
    self = [super init];
    if (self)
    {
        _offlineMapDatabase = offlineMapDatabase;
        [self setupMapID:offlineMapDatabase.mapID includeMetadata:offlineMapDatabase.includesMetadata includeMarkers:offlineMapDatabase.includesMarkers imageQuality:offlineMapDatabase.imageQuality];
    }
    return self;
}

- (void)setupMapID:(NSString *)mapID includeMetadata:(BOOL)includeMetadata includeMarkers:(BOOL)includeMarkers imageQuality:(MBXRasterImageQuality)imageQuality
{
    // Save the map configuration
    //
    _mapID = mapID;
    _imageQuality = imageQuality;
    _metadataURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://a.tiles.mapbox.com/v4/%@.json?secure%@",
                                            _mapID,
                                            [@"&access_token=" stringByAppendingString:[MBXMapKit accessToken]]]];
    _markersURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://a.tiles.mapbox.com/v4/%@/features.json%@",
                                            _mapID,
                                            [@"?access_token=" stringByAppendingString:[MBXMapKit accessToken]]]];

    // Use larger tiles if on retina
    //
    if ([[UIScreen mainScreen] scale] > 1) self.tileSize = CGSizeMake(512, 512);

    // Default to covering up Apple's map
    //
    self.canReplaceMapContent = YES;

    // Default attribution
    self.attribution = @"© Mapbox\n© OpenStreetMap Contributors";

    self.pendingTileRenders = [NSMutableSet new];

    // Initiate asynchronous metadata and marker loading
    //
    if(includeMetadata)
    {
        [self asyncLoadMetadata];
    }
    else
    {
        _didFinishLoadingMetadata = YES;
    }

    if(includeMarkers)
    {
        _mutableMarkers = [[NSMutableArray alloc] init];
        [self asyncLoadMarkers];
    }
    else
    {
        _didFinishLoadingMarkers = YES;
    }
}


- (void)invalidateAndCancel
{
    _delegate = nil;
    _sessionHasBeenInvalidated = YES;
}


#pragma mark - MKTileOverlay implementation

- (MKMapRect)boundingMapRect
{
    // Note: If you're wondering why this doesn't return a MapRect calculated from the TileJSON's bounds, it's been
    // tried and it doesn't work, possibly due to an MKMapKit bug. The main symptom is unpredictable visual glitching.
    //
    return MKMapRectWorld;
}


- (void)loadTileAtPath:(MKTileOverlayPath)path result:(void (^)(NSData *tileData, NSError *error))result
{
    if (_sessionHasBeenInvalidated)
    {
        // If an invalidateAndCancel has been called on this tile overlay layer's data session, bail out immediately.
        //
        return;
    }

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://a.tiles.mapbox.com/v4/%@/%ld/%ld/%ld%@.%@%@",
                                       _mapID,
                                       (long)path.z,
                                       (long)path.x,
                                       (long)path.y,
                                       (path.contentScaleFactor > 1.0 ? @"@2x" : @""),
                                       [MBXRasterTileOverlay qualityExtensionForImageQuality:_imageQuality],
                                       [@"?access_token=" stringByAppendingString:[MBXMapKit accessToken]]
                                       ]];

    MBXRasterTileOverlayCompletionBlock completionHandler = ^(NSData *data, NSError *error) {
        // Invoke the loadTileAtPath's completion handler
        //
        if ([NSThread isMainThread])
        {
            result(data, error);
        }
        else
        {
            dispatch_sync(dispatch_get_main_queue(), ^{
                result(data, error);
            });
        }
    };

    [self setRenderCompletionState:MBXRenderCompletionStateFull
                  ifCurrentStateIs:MBXRenderCompletionStateUnknown];

    [self addPendingRender:url removePendingRender:nil];

    [self asyncLoadURL:url workerBlock:nil completionHandler:completionHandler];
}

#pragma mark - Delegate Notifications

- (void)setDelegate:(id<MBXRasterTileOverlayDelegate>)delegate
{
    _delegate = delegate;

    // If notifications were attempted between initialization and the time the delegate was set, send
    // the saved notifications. This is a normal situation for offline maps because their resources
    // load *very* quickly using operation queues on background threads.
    //
    if(_metadataForPendingNotification || _metadataErrorForPendingNotification)
    {
        [self notifyDelegateDidLoadMetadata:_metadataForPendingNotification withError:_metadataErrorForPendingNotification];
    }
    if(_markersForPendingNotification || _markersErrorForPendingNotification)
    {
        [self notifyDelegateDidLoadMarkers:_markersForPendingNotification withError:_markersErrorForPendingNotification];
    }
    if(_needToNotifyDelegateThatMetadataAndMarkersAreFinished)
    {
        [self notifyDelegateDidFinishLoadingMetadataAndMarkersForOverlay];
    }
}

- (void)notifyDelegateDidLoadMetadata:(NSDictionary *)metadata withError:(NSError *)error
{
    if([_delegate respondsToSelector:@selector(tileOverlay:didLoadMetadata:withError:)])
    {
        _metadataForPendingNotification = nil;
        _metadataErrorForPendingNotification = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate tileOverlay:self didLoadMetadata:metadata withError:error];
        });
    }
    else
    {
        _metadataForPendingNotification = metadata;
        _metadataErrorForPendingNotification = error;
    }
}


- (void)notifyDelegateDidLoadMarkers:(NSArray *)markers withError:(NSError *)error
{
    if([_delegate respondsToSelector:@selector(tileOverlay:didLoadMarkers:withError:)])
    {
        _markersForPendingNotification = nil;
        _markersErrorForPendingNotification = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate tileOverlay:self didLoadMarkers:markers withError:error];
        });
    }
    else
    {
        _markersForPendingNotification = markers;
        _markersErrorForPendingNotification = error;
    }
}


- (void)notifyDelegateDidFinishLoadingMetadataAndMarkersForOverlay
{
    if([_delegate respondsToSelector:@selector(tileOverlayDidFinishLoadingMetadataAndMarkers:)])
    {
        _needToNotifyDelegateThatMetadataAndMarkersAreFinished = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate tileOverlayDidFinishLoadingMetadataAndMarkers:self];
        });
    }
    else
    {
        _needToNotifyDelegateThatMetadataAndMarkersAreFinished = YES;
    }
}



#pragma mark - Methods for asynchronous loading of metadata and markers

- (void)asyncLoadMarkers
{
    // This block is run only if data for the URL is successfully retrieved
    //
    MBXRasterTileOverlayWorkerBlock workerBlock = ^(NSData *data, NSError **error) {
        id markers;
        id value;
        NSDictionary *simplestyleJSONDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
        if(!*error)
        {
            // Find point features in the markers dictionary (if there are any) and add them to the map.
            //
            markers = simplestyleJSONDictionary[@"features"];

            if (markers && [markers isKindOfClass:[NSArray class]])
            {
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
                                // Keep track of how many marker icons are submitted to the download queue
                                //
                                _activeMarkerIconRequests += 1;

                                MBXPointAnnotation *point = [MBXPointAnnotation new];
                                point.title      = title;
                                point.subtitle   = description;
                                point.coordinate = CLLocationCoordinate2DMake([latitude doubleValue], [longitude doubleValue]);

                                NSURL *markerURL = [MBXRasterTileOverlay markerIconURLForSize:size symbol:symbol color:color];
                                [self asyncLoadMarkerIconURL:(NSURL *)markerURL point:point];
                            }
                            else
                            {
                                *error = [self dictionaryErrorMissingImportantKeysFor:@"Markers"];
                            }
                        }
                    }
                    // This is the last line of the loop
                }
            }
        }
    };

    // This block runs at the end of all error handling and data processing associated with the URL
    //
    MBXRasterTileOverlayCompletionBlock completionHandler = ^(NSData *data, NSError *error) {
        if(error) {
            // At this point, it's possible there was an HTTP or network error. It could also be the
            // case that some of the the markers are in the process of successfully loading their icons,
            // but there was a problem with some of the marker JSON (e.g. a bug in the Mapbox API). This
            // takes the fail early and fail hard approach. Any error whatsoever will prevent all the
            // markers from being given to the delegate. The alternative would be to quietly overlook
            // the fact that some of the markers probably didn't load properly.
            //
            _markerIconLoaderMayInitiateDelegateCallback = NO;
            [self notifyDelegateDidLoadMarkers:nil withError:error];

            _didFinishLoadingMarkers = YES;
            if(_didFinishLoadingMetadata) {
                [self notifyDelegateDidFinishLoadingMetadataAndMarkersForOverlay];
            }
        }
        else
        {
            if(_activeMarkerIconRequests <= 0)
            {
                // Handle the case where all the marker icons URLs finished loading before the markers.geojson/features.json finished parsing
                //
                _markers = [NSArray arrayWithArray:_mutableMarkers];
                [self notifyDelegateDidLoadMarkers:_markers withError:error];

                _didFinishLoadingMarkers = YES;
                if(_didFinishLoadingMetadata) {
                    [self notifyDelegateDidFinishLoadingMetadataAndMarkersForOverlay];
                }
                _markerIconLoaderMayInitiateDelegateCallback = NO;
            }
            else
            {
                // There are still icons loading, so let the last one of those handle the delegate callback
                //
                _markerIconLoaderMayInitiateDelegateCallback = YES;
            }
        }
    };

    [self asyncLoadURL:_markersURL workerBlock:workerBlock completionHandler:completionHandler];
}


- (void)asyncLoadMarkerIconURL:(NSURL *)url point:(MBXPointAnnotation *)point
{
    // This block is run only if data for the URL is successfully retrieved
    //
    MBXRasterTileOverlayWorkerBlock workerBlock = ^(NSData *data, NSError **error) {
#if TARGET_OS_IPHONE
        point.image = [[UIImage alloc] initWithData:data scale:[[UIScreen mainScreen] scale]];
#else
        point.image = [[NSImage alloc] initWithData:data];
#endif

        // Add the annotation for this marker icon to the collection of point annotations
        // and update the count of marker icons in the download queue
        //
        [_mutableMarkers addObject:point];
        _activeMarkerIconRequests -= 1;
    };

    // This block runs at the end of all error handling and data processing associated with the URL
    //
    MBXRasterTileOverlayCompletionBlock completionHandler = ^(NSData *data, NSError *error) {
        if(_markerIconLoaderMayInitiateDelegateCallback && _activeMarkerIconRequests <= 0)
        {
            _markers = [NSArray arrayWithArray:_mutableMarkers];
            [self notifyDelegateDidLoadMarkers:_markers withError:error];

            _didFinishLoadingMarkers = YES;
            if(_didFinishLoadingMetadata) {
                [self notifyDelegateDidFinishLoadingMetadataAndMarkersForOverlay];
            }
        }
    };

    [self asyncLoadURL:url workerBlock:workerBlock completionHandler:completionHandler];
}


- (void)asyncLoadMetadata
{
    // This block is run only if data for the URL is successfully retrieved
    //
    MBXRasterTileOverlayWorkerBlock workerBlock = ^(NSData *data, NSError **error) {
        _tileJSONDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
        if(!*error)
        {
            if (_tileJSONDictionary
                && _tileJSONDictionary[@"minzoom"]
                && _tileJSONDictionary[@"maxzoom"]
                && _tileJSONDictionary[@"center"] && [_tileJSONDictionary[@"center"] count] == 3
                && _tileJSONDictionary[@"bounds"] && [_tileJSONDictionary[@"bounds"] count] == 4)
            {
                self.minimumZ = [_tileJSONDictionary[@"minzoom"] integerValue];
                self.maximumZ = [_tileJSONDictionary[@"maxzoom"] integerValue];

                _centerZoom = [_tileJSONDictionary[@"center"][2] integerValue];
                _center.latitude = [_tileJSONDictionary[@"center"][1] doubleValue];
                _center.longitude = [_tileJSONDictionary[@"center"][0] doubleValue];

            }
            else
            {
                *error = [self dictionaryErrorMissingImportantKeysFor:@"Metadata"];
            }
        }
    };

    // This block runs at the end of all error handling and data processing associated with the URL
    //
    MBXRasterTileOverlayCompletionBlock completionHandler = ^(NSData *data, NSError *error) {
        [self notifyDelegateDidLoadMetadata:_tileJSONDictionary withError:error];

        _didFinishLoadingMetadata = YES;
        if(_didFinishLoadingMarkers) {
            [self notifyDelegateDidFinishLoadingMetadataAndMarkersForOverlay];
        }
    };

    [self asyncLoadURL:_metadataURL workerBlock:workerBlock completionHandler:completionHandler];
}


- (void)asyncLoadURL:(NSURL *)url workerBlock:(MBXRasterTileOverlayWorkerBlock)workerBlock completionHandler:(MBXRasterTileOverlayCompletionBlock)completionHandler
{
    // This method exists to:
    // 1. Encapsulte the boilderplate network code for checking HTTP status which is needed for every data session task
    // 2. Provide a single configuration point where it is possible to set breakpoints and adjust the caching policy for all HTTP requests
    // 3. Provide a hook point for implementing alternate methods (i.e. offline map database) of fetching data for a URL
    //

    if (_offlineMapDatabase)
    {
        // If this assert fails, it's probably because MBXOfflineMapDownloader's removeOfflineMapDatabase: method has been invoked
        // for this offline map database object while the database is still associated with a map overlay. That's a serious logic
        // error which should be checked for and avoided.
        //
        assert(_offlineMapDatabase.isInvalid == NO);

        // If an offline map database is configured for this overlay, use the database to fetch data for URLs
        //
        NSError *error;
        NSData *data = [_offlineMapDatabase dataForURL:url withError:&error];
        if(!error)
        {
            // Since the URL was successfully retrieved, invoke the block to process its data
            //
            if (workerBlock) workerBlock(data, &error);
        }
        completionHandler(data,error);

        if (error)
        {
            [self setRenderCompletionState:MBXRenderCompletionStatePartial
                          ifCurrentStateIs:MBXRenderCompletionStateFull];
        }

        [self addPendingRender:nil removePendingRender:url];
    }
    else
    {
        // In the normal case, use HTTP network requests to fetch data for URLs
        //
        [NSURLConnection sendAsynchronousRequest:[[self class] overlayURLRequestForURL:url]
                                           queue:[NSOperationQueue mainQueue]
                               completionHandler:^(NSURLResponse *response, NSData *data, NSError *error)
                               {
                                   NSError *outError = nil;

                                   if (!error)
                                   {
                                       if ([response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse *)response).statusCode != 200)
                                       {
                                           outError = [self statusErrorFromHTTPResponse:response];
                                       }
                                       else
                                       {
                                           // Since the URL was successfully retrieved, invoke the block to process its data
                                           //
                                           if (workerBlock) workerBlock(data, &outError);
                                       }
                                   }
                                   else
                                   {
                                       outError = [error copy];
                                   }

                                   completionHandler(data, outError);

                                   if (outError)
                                   {
                                       [self setRenderCompletionState:MBXRenderCompletionStatePartial
                                                     ifCurrentStateIs:MBXRenderCompletionStateFull];
                                   }

                                   [self addPendingRender:nil removePendingRender:url];
                               }];
    }
}

- (void)addPendingRender:(NSURL *)addURL removePendingRender:(NSURL *)removeURL
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (addURL) [self.pendingTileRenders addObject:addURL];

        if ([self.pendingTileRenders containsObject:removeURL]) [self.pendingTileRenders removeObject:removeURL];

        if ([self.pendingTileRenders count] == 0)
        {
            [NSObject cancelPreviousPerformRequestsWithTarget:self];

            [self performSelector:@selector(notifyRenderDelegateWithSuccess:)
                       withObject:@(self.renderCompletionState == MBXRenderCompletionStateFull)
                       afterDelay:0.5];
        }
    });
}

- (void)notifyRenderDelegateWithSuccess:(NSNumber *)flag
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(tileOverlayDidFinishRendering:fullyRendered:)])
    {
        [self.delegate tileOverlayDidFinishRendering:self fullyRendered:[flag boolValue]];
    }

    [self setRenderCompletionState:MBXRenderCompletionStateUnknown];
}

#pragma mark - Helper methods

- (NSError *)statusErrorFromHTTPResponse:(NSURLResponse *)response
{
    // Return an appropriate NSError for any HTTP response other than 200.
    //
    NSString *reason = [NSString stringWithFormat:@"HTTP status %li was received", (long)((NSHTTPURLResponse *)response).statusCode];

    return [NSError mbx_errorWithCode:MBXMapKitErrorCodeHTTPStatus reason:reason description:@"HTTP status error"];
}


- (NSError *)dictionaryErrorMissingImportantKeysFor:(NSString *)dictionaryName
{
    // Return an appropriate NSError for to indicate that a JSON dictionary was missing important keys.
    //
    NSString *reason = [NSString stringWithFormat:@"The %@ dictionary is missing important keys", dictionaryName];

    return [NSError mbx_errorWithCode:MBXMapKitErrorCodeDictionaryMissingKeys reason:reason description:@"Dictionary missing keys error"];
}

- (void)setRenderCompletionState:(MBXRenderCompletionState)newState
{
    if ( ! [NSThread mainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            _renderCompletionState = newState;
        });
    } else {
        _renderCompletionState = newState;
    }
}

- (void)setRenderCompletionState:(MBXRenderCompletionState)newState ifCurrentStateIs:(MBXRenderCompletionState)checkState
{
    if ( ! [NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (_renderCompletionState == checkState) {
                _renderCompletionState = newState;
            }
        });
    } else {
        if (_renderCompletionState == checkState) {
            _renderCompletionState = newState;
        }
    }
}

#pragma mark - Methods for clearing cached metadata and markers

- (void)clearCachedMetadata
{
    NSURLRequest *request = [[self class] overlayURLRequestForURL:_metadataURL];
    [[[self class] overlayURLCache] removeCachedResponseForRequest:request];
}

- (void)clearCachedMarkers
{
    NSURLRequest *request = [[self class] overlayURLRequestForURL:_markersURL];
    [[[self class] overlayURLCache] removeCachedResponseForRequest:request];
}



@end
