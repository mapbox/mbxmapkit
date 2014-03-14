//
//  MBXRasterTileOverlay.m
//  MBXMapKit
//
//  Created by Will Snook on 3/2/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXRasterTileOverlay.h"

#pragma mark - Notification strings for cache and network statistics

NSString * const MBXNotificationTypeCacheHit = @"com.mapbox.mbxmapkit.stats.cacheHit";
NSString * const MBXNotificationTypeHTTPSuccess = @"com.mapbox.mbxmapkit.stats.httpSuccess";
NSString * const MBXNotificationTypeHTTPFailure = @"com.mapbox.mbxmapkit.stats.httpFailure";
NSString * const MBXNotificationTypeNetworkFailure = @"com.mapbox.mbxmapkit.stats.networkFailure";


#pragma mark - Constants for the MBXMapKit error domain

NSString *const MBXMapKitErrorDomain = @"MBXMapKitErrorDomain";
NSInteger const MBXMapKitErrorCodeHTTPStatus = -1;
NSInteger const MBXMapKitErrorCodeDictionaryMissingKeys = -2;


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
@property (nonatomic) NSURLSession *markerIconDataSession;
@property (nonatomic) NSDictionary *tileJSONDictionary;
@property (nonatomic) NSDictionary *simplestyleJSONDictionary;
@property (nonatomic) BOOL sessionHasBeenInvalidated;
@property (nonatomic) NSURL *metadataURL;
@property (nonatomic) NSURL *markersURL;
@property (nonatomic) NSMutableArray *mutableMarkers;

@end


#pragma mark - MBXRasterTileOverlay, a subclass of MKTileOverlay

@implementation MBXRasterTileOverlay


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
    _markerIconDataSession = [NSURLSession sessionWithConfiguration:config];


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
    if(markers)
    {
        [self asyncLoadMarkers];
    }
}


- (void)invalidateAndCancel
{
    _delegate = nil;
    _sessionHasBeenInvalidated = YES;
    [_dataSession invalidateAndCancel];
    [_markerIconDataSession invalidateAndCancel];
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
                                       [self qualityExtensionForImageQuality:_imageQuality]
                                       ]];

    NSURLSessionDataTask *dataTask;
    dataTask = [self.dataSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
    {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        if (error)
        {
            [center postNotificationName:MBXNotificationTypeNetworkFailure object:self];
        }
        else if ([response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse *)response).statusCode != 200)
        {
            error = [self statusErrorFromHTTPResponse:response];
            [center postNotificationName:MBXNotificationTypeHTTPFailure object:self];
        }
        else
        {
            [center postNotificationName:MBXNotificationTypeHTTPSuccess object:self];
        }

        // Invoke the loadTileAtPath's completion handler
        //
        result(data, error);
    }];
    [dataTask resume];
}


#pragma mark - Methods for asynchronous loading of metadata and markers

- (void)asyncLoadMarkers
{
    NSURLSessionDataTask *task;
    task = [self.dataSession dataTaskWithURL:_markersURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
    {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        if (error)
        {
            [center postNotificationName:MBXNotificationTypeNetworkFailure object:self];
        }
        else if ([response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse *)response).statusCode != 200)
        {
            [center postNotificationName:MBXNotificationTypeHTTPFailure object:self];
            error = [self statusErrorFromHTTPResponse:response];
        }
        else
        {
            [center postNotificationName:MBXNotificationTypeHTTPSuccess object:self];

            NSError *parseError;
            id markers;
            id value;
            NSDictionary *simplestyleJSONDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
            if(!parseError)
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
                                    MBXPointAnnotation *point = [MBXPointAnnotation new];
                                    point.title      = title;
                                    point.subtitle   = description;
                                    point.coordinate = CLLocationCoordinate2DMake([latitude doubleValue], [longitude doubleValue]);

                                    NSURL *markerURL = [self markerIconURLForSize:size symbol:symbol color:color];
                                    [self asyncLoadMarkerURL:(NSURL *)markerURL point:point];
                                }
                                else
                                {
                                    parseError = [self dictionaryErrorMissingImportantKeysFor:@"Metadata"];
                                }
                            }
                        } // End  of for(...)
                    }
                }
            }

        }
    }];
    [task resume];
}


- (NSURL *)markerIconURLForSize:(NSString *)size symbol:(NSString *)symbol color:(NSString *)color
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


- (void)asyncLoadMarkerURL:(NSURL *)url point:(MBXPointAnnotation *)point
{
    NSURLSessionDataTask *task;
    task = [self.markerIconDataSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
    {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        if (error)
        {
            [center postNotificationName:MBXNotificationTypeNetworkFailure object:self];
        }
        else if ([response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse *)response).statusCode != 200)
        {
            [center postNotificationName:MBXNotificationTypeHTTPFailure object:self];
            error = [self statusErrorFromHTTPResponse:response];
        }
        else
        {
            [center postNotificationName:MBXNotificationTypeHTTPSuccess object:self];

#if TARGET_OS_IPHONE
            point.image = [[UIImage alloc] initWithData:data scale:[[UIScreen mainScreen] scale]];
#else
            point.image = [[NSImage alloc] initWithData:data];
#endif

            [self.mutableMarkers addObject:point];
        }
    }];
    [task resume];
}


- (void)asyncLoadURL:(NSURL *)url usingSession:(NSURLSession *)session successCompletionHandler:(void(^)())success
{
    NSURLSessionDataTask *task;
    task = [session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
    {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        if (error)
        {
            [center postNotificationName:MBXNotificationTypeNetworkFailure object:self];
        }
        else if ([response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse *)response).statusCode != 200)
        {
            [center postNotificationName:MBXNotificationTypeHTTPFailure object:self];
            error = [self statusErrorFromHTTPResponse:response];
        }
        else
        {
            [center postNotificationName:MBXNotificationTypeHTTPSuccess object:self];

            // Invoke the completion handler
            //
            success();
        }
    }];
    [task resume];
}


- (void)asyncLoadMetadata
{
    NSURLSessionDataTask *task;
    task = [self.dataSession dataTaskWithURL:_metadataURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
    {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        if (error)
        {
            [center postNotificationName:MBXNotificationTypeNetworkFailure object:self];
        }
        else if ([response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse *)response).statusCode != 200)
        {
            [center postNotificationName:MBXNotificationTypeHTTPFailure object:self];
            error = [self statusErrorFromHTTPResponse:response];
        }
        else
        {
            [center postNotificationName:MBXNotificationTypeHTTPSuccess object:self];
            _tileJSONDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if(!error)
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
                    error = [self dictionaryErrorMissingImportantKeysFor:@"Metadata"];
                }
            }
        }
        [_delegate MBXRasterTileOverlay:self didLoadMetadata:_tileJSONDictionary withError:error];

    }];
    [task resume];
}


#pragma mark - Helper methods

- (NSError *)statusErrorFromHTTPResponse:(NSURLResponse *)response
{
    // Return an appropriate NSError for any HTTP response other than 200.
    //
    NSString *errorReason = [NSString stringWithFormat:@"HTTP status %li was received", (long)((NSHTTPURLResponse *)response).statusCode];

    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey        : NSLocalizedString(@"HTTP status error", nil),
                                NSLocalizedFailureReasonErrorKey : NSLocalizedString(errorReason, nil) };

    return [NSError errorWithDomain:MBXMapKitErrorDomain code:MBXMapKitErrorCodeHTTPStatus userInfo:userInfo];
}


- (NSError *)dictionaryErrorMissingImportantKeysFor:(NSString *)dictionaryName
{
    // Return an appropriate NSError for to indicate that a JSON dictionary was missing important keys.
    //
    NSString *errorReason = [NSString stringWithFormat:@"The %@ dictionary is missing important keys", dictionaryName];

    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey        : NSLocalizedString(@"Dictionary missing keys error", nil),
                                NSLocalizedFailureReasonErrorKey : NSLocalizedString(errorReason, nil) };

    return [NSError errorWithDomain:MBXMapKitErrorDomain code:MBXMapKitErrorCodeDictionaryMissingKeys userInfo:userInfo];
}



- (NSString *)qualityExtensionForImageQuality:(MBXRasterImageQuality)imageQuality
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
