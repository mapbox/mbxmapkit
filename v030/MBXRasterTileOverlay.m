//
//  MBXRasterTileOverlay.m
//  MBXMapKit
//
//  Created by Will Snook on 3/2/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXRasterTileOverlay.h"
#import "MBXError.h"
#import "MBXPointAnnotation.h"
#import "MBXOfflineMapDatabase.h"


#pragma mark -

@interface MBXRasterTileOverlay ()


#pragma mark - Private read-write backing properties for public read-only properties

@property (readwrite,nonatomic) NSString *mapID;
@property (readwrite,nonatomic) MBXRasterImageQuality imageQuality;
@property (readwrite,nonatomic) CLLocationCoordinate2D center;
@property (readwrite,nonatomic) NSInteger centerZoom;
@property (readwrite,nonatomic) NSArray *markers;


#pragma mark - Properties for asynchronous downloading of metadata and markers

@property (nonatomic) NSURLSession *dataSession;
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


+ (NSURL *)markerIconURLForSize:(NSString *)size symbol:(NSString *)symbol color:(NSString *)color
{
    // Make a string which follows the MapBox Core API spec for stand-alone markers. This relies on the MapBox API
    // for error checking.
    //
    NSMutableString *marker = [[NSMutableString alloc] initWithString:@"pin-"];

    if ([size hasPrefix:@"l"])
    {
        [marker appendString:@"l-"]; // large
    }
    else if ([size hasPrefix:@"s"])
    {
        [marker appendString:@"s-"]; // small
    }
    else
    {
        [marker appendString:@"m-"]; // default to medium
    }

    [marker appendFormat:@"%@+",symbol];

    [marker appendString:[color stringByReplacingOccurrencesOfString:@"#" withString:@""]];

#if TARGET_OS_IPHONE
    [marker appendString:([[UIScreen mainScreen] scale] > 1.0 ? @"@2x.png" : @".png")];
#else
    // Making this smart enough to handle a Retina MacBook with a normal dpi external display is complicated.
    // For now, just default to @1x images and a 1.0 scale.
    //
    [marker appendString:@".png"];
#endif

    return [NSURL URLWithString:[NSString stringWithFormat:@"https://a.tiles.mapbox.com/v3/marker/%@", marker]];
}


#pragma mark - Initialization

- (id)initWithMapID:(NSString *)mapID;
{
    self = [super init];
    if (self)
    {
        [self setupMapID:mapID metadata:YES markers:YES imageQuality:MBXRasterImageQualityFull];
    }
    return self;
}


- (id)initWithMapID:(NSString *)mapID metadata:(BOOL)metadata markers:(BOOL)markers
{
    self = [super init];
    if (self)
    {
        [self setupMapID:mapID metadata:metadata markers:markers imageQuality:MBXRasterImageQualityFull];
    }
    return self;
}


- (id)initWithMapID:(NSString *)mapID metadata:(BOOL)metadata markers:(BOOL)markers imageQuality:(MBXRasterImageQuality)imageQuality
{
    self = [super init];
    if (self)
    {
        [self setupMapID:mapID metadata:metadata markers:markers imageQuality:imageQuality];
    }
    return self;
}

- (id)initWithOfflineMapDatabase:(MBXOfflineMapDatabase *)offlineMapDatabase delegate:(id<MBXRasterTileOverlayDelegate>)delegate
{
    self = [super init];
    if (self)
    {
        _offlineMapDatabase = offlineMapDatabase;
        _delegate = delegate;
        [self setupMapID:offlineMapDatabase.mapID metadata:offlineMapDatabase.metadata markers:offlineMapDatabase.markers imageQuality:offlineMapDatabase.imageQuality];
    }
    return self;
}


- (void)setupMapID:(NSString *)mapID metadata:(BOOL)metadata markers:(BOOL)markers imageQuality:(MBXRasterImageQuality)imageQuality
{
    // Configure the NSURLSessions
    //
    NSString *userAgent;
#if TARGET_OS_IPHONE
    userAgent = [NSString stringWithFormat:@"MBXMapKit (%@/%@)", [[UIDevice currentDevice] model], [[UIDevice currentDevice] systemVersion]];
#else
    userAgent = [NSString stringWithFormat:@"MBXMapKit (OS X/%@)", [[NSProcessInfo processInfo] operatingSystemVersionString]];
#endif

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.allowsCellularAccess = YES;
    config.HTTPMaximumConnectionsPerHost = 16;
    config.URLCache = [NSURLCache sharedURLCache];
    config.HTTPAdditionalHeaders = @{ @"User-Agent" : userAgent };
    _dataSession = [NSURLSession sessionWithConfiguration:config];


    // Save the map configuration
    //
    _mapID = mapID;
    _imageQuality = imageQuality;
    _metadataURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://a.tiles.mapbox.com/v3/%@.json", _mapID]];
    _markersURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://a.tiles.mapbox.com/v3/%@/markers.geojson", _mapID]];


    // Default to covering up Apple's map
    //
    self.canReplaceMapContent = YES;


    // Initiate asynchronous metadata and marker loading
    //
    if(metadata)
    {
        [self asyncLoadMetadata];
    }
    else
    {
        _didFinishLoadingMetadata = YES;
    }

    if(markers)
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
    [_dataSession invalidateAndCancel];
}


#pragma mark - MKTileOverlay implementation

- (MKMapRect)boundingMapRect
{
    // Note: If you're wondering why this doesn't return a MapRect calculated from the TileJSON's bounds, it's been
    // tried and it doesn't work, possibly due to an MKMapKit bug. The main symptom is unpredictable visual glitching.
    //
    return MKMapRectWorld;
}


- (void)loadTileAtPath:(MKTileOverlayPath)path result:(void (^)(NSData *, NSError *))result
{
    if (_sessionHasBeenInvalidated)
    {
        // If an invalidateAndCancel has been called on this tile overlay layer's data session, bail out immediately.
        //
        return;
    }

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://a.tiles.mapbox.com/v3/%@/%ld/%ld/%ld%@.%@",
                                       _mapID,
                                       (long)path.z,
                                       (long)path.x,
                                       (long)path.y,
                                       (path.contentScaleFactor > 1.0 ? @"@2x" : @""),
                                       [MBXRasterTileOverlay qualityExtensionForImageQuality:_imageQuality]
                                       ]];

    void(^dataBlock)(NSData *,NSError **) = ^(NSData *data, NSError **error)
    {
        // No special actions need to be taken here
    };

    void(^completionHandler)(NSData *,NSError *) = ^(NSData *data, NSError *error)
    {
        // Invoke the loadTileAtPath's completion handler
        //
        result(data, error);
    };

    [self asyncLoadURL:url dataBlock:dataBlock completionHandler:completionHandler];
}


#pragma mark - Methods for asynchronous loading of metadata and markers

- (void)asyncLoadMarkers
{
    // This block is run only if data for the URL is successfully retrieved
    //
    void(^dataBlock)(NSData *,NSError **) = ^(NSData *data, NSError **error)
    {
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
    void(^completionHandler)(NSData *,NSError *) = ^(NSData *data, NSError *error)
    {
        if(error) {
            // At this point, it's possible there was an HTTP or network error. It could also be the
            // case that some of the the markers are in the process of successfully loading their icons,
            // but there was a problem with some of the marker JSON (e.g. a bug in the Mapbox API). This
            // takes the fail early and fail hard approach. Any error whatsoever will prevent all the
            // markers from being given to the delegate. The alternative would be to quietly overlook
            // the fact that some of the markers probably didn't load properly.
            //
            _markerIconLoaderMayInitiateDelegateCallback = NO;
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [_delegate tileOverlay:self didLoadMarkers:nil withError:error];
            });

            _didFinishLoadingMarkers = YES;
            if(_didFinishLoadingMetadata) {
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    [_delegate tileOverlayDidFinishLoadingMetadataAndMarkersForOverlay:self];
                });
            }
        }
        else
        {
            _markerIconLoaderMayInitiateDelegateCallback = YES;
        }
    };

    [self asyncLoadURL:_markersURL dataBlock:dataBlock completionHandler:completionHandler];
}


- (void)asyncLoadMarkerIconURL:(NSURL *)url point:(MBXPointAnnotation *)point
{
    // This block is run only if data for the URL is successfully retrieved
    //
    void(^dataBlock)(NSData *,NSError **) = ^(NSData *data, NSError **error){

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
    void(^completionHandler)(NSData *,NSError *) = ^(NSData *data, NSError *error)
    {
        if(_markerIconLoaderMayInitiateDelegateCallback && _activeMarkerIconRequests <= 0)
        {
            _markers = [NSArray arrayWithArray:_mutableMarkers];
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [_delegate tileOverlay:self didLoadMarkers:_markers withError:error];
            });

            _didFinishLoadingMarkers = YES;
            if(_didFinishLoadingMetadata) {
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    [_delegate tileOverlayDidFinishLoadingMetadataAndMarkersForOverlay:self];
                });
            }
        }
    };

    [self asyncLoadURL:url dataBlock:dataBlock completionHandler:completionHandler];
}


- (void)asyncLoadMetadata
{
    // This block is run only if data for the URL is successfully retrieved
    //
    void(^dataBlock)(NSData *,NSError **) = ^(NSData *data, NSError **error)
    {
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
    void(^completionHandler)(NSData *,NSError *) = ^(NSData *data, NSError *error)
    {
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [_delegate tileOverlay:self didLoadMetadata:_tileJSONDictionary withError:error];
        });

        _didFinishLoadingMetadata = YES;
        if(_didFinishLoadingMarkers) {
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [_delegate tileOverlayDidFinishLoadingMetadataAndMarkersForOverlay:self];
            });
        }
    };

    [self asyncLoadURL:_metadataURL dataBlock:dataBlock completionHandler:completionHandler];
}


- (void)asyncLoadURL:(NSURL *)url dataBlock:(void(^)(NSData *,NSError **))dataBlock completionHandler:(void (^)(NSData *, NSError *))completionHandler
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
        assert(_offlineMapDatabase.invalid == NO);

        // If an offline map database is configured for this overlay, use the database to fetch data for URLs
        //
        NSError *error;
        NSData *data = [_offlineMapDatabase dataForURL:url withError:&error];
        if(!error)
        {
            // Since the URL was successfully retrieved, invoke the block to process its data
            //
            dataBlock(data, &error);
        }
        completionHandler(data,error);
    }
    else
    {
        // In the normal case, use HTTP network requests to fetch data for URLs
        //
        NSURLSessionDataTask *task;
        NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60];
        task = [_dataSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
        {
            if (!error)
            {
                if ([response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse *)response).statusCode != 200)
                {
                    error = [self statusErrorFromHTTPResponse:response];
                }
                else
                {
                    // Since the URL was successfully retrieved, invoke the block to process its data
                    //
                    dataBlock(data,&error);
                }
            }

            completionHandler(data,error);
        }];
        [task resume];
    }
}


#pragma mark - Helper methods

- (NSError *)statusErrorFromHTTPResponse:(NSURLResponse *)response
{
    // Return an appropriate NSError for any HTTP response other than 200.
    //
    NSString *reason = [NSString stringWithFormat:@"HTTP status %li was received", (long)((NSHTTPURLResponse *)response).statusCode];

    return [MBXError errorWithCode:MBXMapKitErrorCodeHTTPStatus reason:reason description:@"HTTP status error"];
}


- (NSError *)dictionaryErrorMissingImportantKeysFor:(NSString *)dictionaryName
{
    // Return an appropriate NSError for to indicate that a JSON dictionary was missing important keys.
    //
    NSString *reason = [NSString stringWithFormat:@"The %@ dictionary is missing important keys", dictionaryName];

    return [MBXError errorWithCode:MBXMapKitErrorCodeDictionaryMissingKeys reason:reason description:@"Dictionary missing keys error"];
}


#pragma mark - Methods for clearing cached metadata and markers

- (void)clearCachedMetadata
{
    NSURLRequest *request = [NSURLRequest requestWithURL:_metadataURL];
    [_dataSession.configuration.URLCache removeCachedResponseForRequest:request];
}

- (void)clearCachedMarkers
{
    NSURLRequest *request = [NSURLRequest requestWithURL:_markersURL];
    [_dataSession.configuration.URLCache removeCachedResponseForRequest:request];
}



@end
