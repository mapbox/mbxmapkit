//
//  MBXRasterTileOverlay.m
//  MBXMapKit
//
//  Created by Will Snook on 3/2/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXRasterTileOverlay.h"

#pragma mark - Notification strings for cache and network statistics

NSString * const MBXNotificationTypeCacheHit = @"MBXNotificationTypeCacheHit";
NSString * const MBXNotificationTypeHTTPSuccess = @"MBXNotificationTypeHTTPSuccess";
NSString * const MBXNotificationTypeHTTPFailure = @"MBXNotificationTypeHTTPFailure";
NSString * const MBXNotificationTypeNetworkFailure = @"MBXNotificationTypeNetworkFailure";
NSString * const MBXNotificationUserInfoKeyError = @"MBXNotificationUserInfoKeyError";


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


#pragma mark - Properties for asynchronous downloading of metadata and markers

@property (nonatomic) NSURLSession *dataSession;
@property (nonatomic) NSDictionary *tileJSONDictionary;
@property (nonatomic) NSDictionary *simplestyleJSONDictionary;

@end


#pragma mark -

@implementation MBXRasterTileOverlay


#pragma mark - Initialization

- (id)initWithMapID:(NSString *)mapID;
{
    self = [super init];

    if (self)
    {
        [self configureRasterTileOverlayMapID:mapID
                                 loadMetadata:YES
                                  loadMarkers:YES
                                 imageQuality:MBXRasterImageQualityFull
         ];
    }

    return self;
}

- (id)initWithMapID:(NSString *)mapID loadMetadata:(BOOL)loadMetadata loadMarkers:(BOOL)loadMarkers
{
    self = [super init];

    if (self)
    {
        [self configureRasterTileOverlayMapID:mapID
                                 loadMetadata:loadMetadata
                                  loadMarkers:loadMarkers
                                 imageQuality:MBXRasterImageQualityFull
         ];
    }

    return self;
}

- (id)initWithMapID:(NSString *)mapID loadMetadata:(BOOL)loadMetadata loadMarkers:(BOOL)loadMarkers imageQuality:(MBXRasterImageQuality)imageQuality
{
    self = [super init];

    if (self)
    {
        [self configureRasterTileOverlayMapID:mapID
                                 loadMetadata:loadMetadata
                                  loadMarkers:loadMarkers
                                 imageQuality:imageQuality
         ];
    }

    return self;
}


- (void)configureRasterTileOverlayMapID:(NSString *)mapID loadMetadata:(BOOL)loadMetadata loadMarkers:(BOOL)loadMarkers imageQuality:(MBXRasterImageQuality)imageQuality
{
    // Configure the NSURLSession
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


    // Default to covering up Apple's map
    //
    self.canReplaceMapContent = YES;


    // Initiate asynchronous metadata and marker loading
    //
    if(loadMetadata)
    {
        [self asyncLoadMetadata];
    }
    if(loadMarkers)
    {
        [self asyncLoadMarkers];
    }
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
        NSError *statusError;
        if (error)
        {
            // Reaching this point means there is a networking problem such as airplane mode being turned on.
            //
            [center postNotificationName:MBXNotificationTypeNetworkFailure object:self userInfo:@{ @"error" : error }];
        }
        else if ([response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse *)response).statusCode != 200)
        {
            // Reaching this point means the HTTP response was HTTP, but not an HTTP 200.
            //
            statusError = [self statusErrorFromHTTPResponse:response];
            [center postNotificationName:MBXNotificationTypeHTTPFailure object:self  userInfo:@{ @"error" : statusError }];
        }
        else
        {
            // Reaching this point means should mean the request was successful
            //
            [center postNotificationName:MBXNotificationTypeHTTPSuccess object:self];
        }

        // Invoke the loadTileAtPath's completion handler
        //
        if(statusError)
        {
            result(data, statusError);
        }
        else if(error)
        {
            result(data, error);
        }
        else
        {
            result(data, nil);
        }
    }];
    [dataTask resume];
}


#pragma mark - Methods for asynchronous loading of metadata and markers

- (void)asyncLoadMarkers
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://a.tiles.mapbox.com/v3/%@/markers.geojson", _mapID]];
    NSURLSessionDataTask *dataTask;
    dataTask = [self.dataSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
    {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        NSError *statusError;
        if (error)
        {
            // Reaching this point means there is a networking problem such as airplane mode being turned on.
            //
            [center postNotificationName:MBXNotificationTypeNetworkFailure object:self userInfo:@{ @"error" : error }];

            if([_delegate respondsToSelector:@selector(MBXRasterTileOverlay:didFailLoadingMarkersWithError:)])
            {
                [_delegate MBXRasterTileOverlay:self didFailLoadingMarkersWithError:error];
            }
        }
        else if ([response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse *)response).statusCode != 200)
        {
            // Reaching this point means the HTTP response was HTTP, but not an HTTP 200.
            //
            statusError = [self statusErrorFromHTTPResponse:response];
            [center postNotificationName:MBXNotificationTypeHTTPFailure object:self  userInfo:@{ @"error" : statusError }];

            if([_delegate respondsToSelector:@selector(MBXRasterTileOverlay:didFailLoadingMarkersWithError:)])
            {
                [_delegate MBXRasterTileOverlay:self didFailLoadingMarkersWithError:statusError];
            }
        }
        else
        {
            // Reaching this point means should mean the request was successful
            //
            [center postNotificationName:MBXNotificationTypeHTTPSuccess object:self];

            NSError *parseError;
            id markers;
            NSDictionary *simplestyleJSONDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
            if(!parseError)
            {
                markers = simplestyleJSONDictionary[@"features"];
            }
            else
            {
                if ([_delegate respondsToSelector:@selector(MBXRasterTileOverlay:didFailLoadingMarkersWithError:)]) {
                    [_delegate MBXRasterTileOverlay:self didFailLoadingMarkersWithError:parseError];
                }
            }

            // Find point features in the markers dictionary (if there are any) and add them to the map.
            //
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

                                MBXPointAnnotation *point = [MBXPointAnnotation new];

                                point.title      = title;
                                point.subtitle   = description;
                                point.coordinate = CLLocationCoordinate2DMake([latitude doubleValue], [longitude doubleValue]);

                                [self asyncLoadMarkerIconSize:size symbol:symbol color:color point:point];
                            }
                            else
                            {
                                if ([_delegate respondsToSelector:@selector(MBXRasterTileOverlay:didFailLoadingMarkersWithError:)]) {
                                    if(parseError)
                                    {
                                        [_delegate MBXRasterTileOverlay:self didFailLoadingMetadataWithError:parseError];
                                    }
                                    else
                                    {
                                        NSError *keysError = [self dictionaryErrorMissingImportantKeysFor:@"Metadata"];
                                        [_delegate MBXRasterTileOverlay:self didFailLoadingMetadataWithError:keysError];
                                    }
                                }
                            }
                        }
                    }
                }
            }

        }
    }];
    [dataTask resume];
}


- (void)asyncLoadMarkerIconSize:(NSString *)size symbol:(NSString *)symbol color:(NSString *)color point:(MBXPointAnnotation *)point
{
    // Make a string which follows the MapBox Core API spec for stand-alone markers. This relies on the MapBox API
    // for error checking rather than trying to do any fancy tricks to determine valid size-symbol-color combinations.
    // The main advantage of that approach is that new Maki symbols will be available to use as markers as soon as
    // they are added to the API (i.e. no changes to input validation code here are required).
    // See https://www.mapbox.com/developers/api/#Stand-alone.markers
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

    // Attempt to fetch a marker icon from the cache if it's available, or by downloading it if not
    //
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://a.tiles.mapbox.com/v3/marker/%@", marker]];
    NSURLSessionDataTask *dataTask;
    dataTask = [self.dataSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
    {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        NSError *statusError;
        if (error)
        {
            // Reaching this point means there is a networking problem such as airplane mode being turned on.
            //
            [center postNotificationName:MBXNotificationTypeNetworkFailure object:self userInfo:@{ @"error" : error }];

            if([_delegate respondsToSelector:@selector(MBXRasterTileOverlay:didFailLoadingMarkersWithError:)])
            {
                [_delegate MBXRasterTileOverlay:self didFailLoadingMarkersWithError:error];
            }
        }
        else if ([response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse *)response).statusCode != 200)
        {
            // Reaching this point means the HTTP response was HTTP, but not an HTTP 200.
            //
            statusError = [self statusErrorFromHTTPResponse:response];
            [center postNotificationName:MBXNotificationTypeHTTPFailure object:self  userInfo:@{ @"error" : statusError }];

            if([_delegate respondsToSelector:@selector(MBXRasterTileOverlay:didFailLoadingMarkersWithError:)])
            {
                [_delegate MBXRasterTileOverlay:self didFailLoadingMarkersWithError:statusError];
            }
        }
        else
        {
            // Reaching this point means should mean the request was successful
            //
            [center postNotificationName:MBXNotificationTypeHTTPSuccess object:self];

#if TARGET_OS_IPHONE
            point.image = [[UIImage alloc] initWithData:data scale:[[UIScreen mainScreen] scale]];
#else
            // Making this smart enough to handle a Retina MacBook with a normal dpi external display is complicated.
            // For now, just default to @1x images and a 1.0 scale.
            //
            point.image = [[NSImage alloc] initWithData:data];
#endif

            if ([_delegate respondsToSelector:@selector(MBXRasterTileOverlay:didLoadMarker:)])
            {
                [_delegate MBXRasterTileOverlay:self didLoadMarker:point];
            }
        }
    }];
    [dataTask resume];
}





- (void)asyncLoadMetadata
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://a.tiles.mapbox.com/v3/%@.json", _mapID]];

    NSURLSessionDataTask *dataTask;
    dataTask = [self.dataSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
    {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        NSError *statusError;
        if (error)
        {
            // Reaching this point means there is a networking problem such as airplane mode being turned on.
            //
            [center postNotificationName:MBXNotificationTypeNetworkFailure object:self userInfo:@{ @"error" : error }];

            if([_delegate respondsToSelector:@selector(MBXRasterTileOverlay:didFailLoadingMetadataWithError:)])
            {
                [_delegate MBXRasterTileOverlay:self didFailLoadingMetadataWithError:error];
            }
        }
        else if ([response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse *)response).statusCode != 200)
        {
            // Reaching this point means the HTTP response was HTTP, but not an HTTP 200.
            //
            statusError = [self statusErrorFromHTTPResponse:response];
            [center postNotificationName:MBXNotificationTypeHTTPFailure object:self  userInfo:@{ @"error" : statusError }];

            if([_delegate respondsToSelector:@selector(MBXRasterTileOverlay:didFailLoadingMetadataWithError:)])
            {
                [_delegate MBXRasterTileOverlay:self didFailLoadingMetadataWithError:statusError];
            }
        }
        else
        {
            // Reaching this point means should mean the request was successful
            //
            [center postNotificationName:MBXNotificationTypeHTTPSuccess object:self];
            NSError *parseError;
            NSDictionary *tileJSONDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
            if(
               !parseError
               && tileJSONDictionary
               && tileJSONDictionary[@"minzoom"]
               && tileJSONDictionary[@"maxzoom"]
               && tileJSONDictionary[@"center"] && [tileJSONDictionary[@"center"] count] == 3
               && tileJSONDictionary[@"bounds"] && [tileJSONDictionary[@"bounds"] count] == 4
               )
            {
                // Setting these zoom limits theoretically might help to cut down on 404's for zoom levels that aren't part
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


                // Save the TileJSON.
                //
                [self setTileJSONDictionary:tileJSONDictionary];
                if ([_delegate respondsToSelector:@selector(MBXRasterTileOverlay:didLoadMetadata:)])
                {
                    [_delegate MBXRasterTileOverlay:self didLoadMetadata:tileJSONDictionary];
                }
            }
            else
            {
                if([_delegate respondsToSelector:@selector(MBXRasterTileOverlay:didFailLoadingMetadataWithError:)])
                {
                    if(parseError)
                    {
                        [_delegate MBXRasterTileOverlay:self didFailLoadingMetadataWithError:parseError];
                    }
                    else
                    {
                        NSError *keysError = [self dictionaryErrorMissingImportantKeysFor:@"Metadata"];
                        [_delegate MBXRasterTileOverlay:self didFailLoadingMetadataWithError:keysError];
                    }
                }
            }
        }
    }];
    [dataTask resume];
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

}

- (void)clearCachedMarkers
{

}



@end
