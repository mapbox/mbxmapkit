//
//  MBXCacheManager.m
//  MBXMapKit
//
//  Created by Will Snook on 3/2/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXCacheManager.h"

@implementation MBXCacheManager

#pragma mark - Notification strings for cache statistics

NSString * const MBXNotificationCacheHit = @"MBXNotificationCacheHit";

NSString * const MBXNotificationHTTPSuccess = @"MBXNotificationHTTPSuccess";

NSString * const MBXNotificationHTTPFailure = @"MBXNotificationHTTPFailure";


#pragma mark - Constants for the MBXMapKit error domain

NSString *const MBXMapKitErrorDomain = @"MBXMapKitErrorDomain";

NSInteger const MBXMapKitErrorCodeHTTPStatus = -1;


#pragma mark - Shared cache manager singelton

+ (MBXCacheManager *)sharedCacheManager
{
    static MBXCacheManager *sharedCacheManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCacheManager = [[self alloc] init];
    });
    return sharedCacheManager;
}


#pragma mark - Methods for proxying resources through the cache


- (NSData *)proxyTileJSONForMapID:(NSString *)mapID withError:(NSError **)error
{
    // Attempt to fetch some TileJSON from the cache if it's available, or by downloading it if not
    //
    return [self proxyResourceDescription:@"TileJSON"
                                urlString:[NSString stringWithFormat:@"https://a.tiles.mapbox.com/v3/%@.json", mapID]
                                    error:error
            ];
}


- (NSData *)proxySimplestyleForMapID:(NSString *)mapID withError:(NSError **)error
{
    // Attempt to fetch some simplestyle from the cache if it's available, or by downloading it if not
    //
    return [self proxyResourceDescription:@"Simplestyle"
                                urlString:[NSString stringWithFormat:@"https://a.tiles.mapbox.com/v3/%@/markers.geojson", mapID]
                                    error:error
            ];
}


- (NSData *)proxyTileAtPath:(MKTileOverlayPath)path forMapID:(NSString *)mapID withQuality:(MBXRasterImageQuality)imageQuality withError:(NSError **)error
{
    NSString *urlString = [NSString stringWithFormat:@"https://a.tiles.mapbox.com/v3/%@/%ld/%ld/%ld%@.%@",
                           mapID,
                           (long)path.z,
                           (long)path.x,
                           (long)path.y,
                           (path.contentScaleFactor > 1.0 ? @"@2x" : @""),
                           [self qualityExtensionForImageQuality:imageQuality]
                           ];

    return [self proxyResourceDescription:@"Tile"
                                urlString:urlString
                                    error:error
            ];
}

- (NSData *)proxyMarkerIconSize:(NSString *)size symbol:(NSString *)symbol color:(NSString *)color error:(NSError **)error
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
    return [self proxyResourceDescription:@"Marker icon"
                                urlString:[NSString stringWithFormat:@"https://a.tiles.mapbox.com/v3/marker/%@", marker]
                                    error:error
            ];
}


#pragma mark - Methods for invalidating portions of the cache

- (void)clearMapID:(NSString *)mapID
{
}


- (void)clearSimplestyleForMapID:(NSString *)mapID
{
}


- (void)clearMarkerIcons
{
}


- (void)clearEntireCache
{
}



#pragma mark - Private implementation methods

- (NSData *)proxyResourceDescription:(NSString *)description urlString:(NSString *)urlString error:(NSError **)error
{
    // Make the point that we had better not be blocking the main thread here
    //
    assert(![NSThread isMainThread]);

    NSURL *url = [NSURL URLWithString:urlString];

    // Do a synchronous request for the specified URL. Synchronous is fine, because this should have been wrapped with dispatch_async()
    // somewhere up the call stack.
    //
    NSData *data;
    NSMutableURLRequest *request;
    NSURLResponse *response;
    NSError *err;
    request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadRevalidatingCacheData timeoutInterval:60.0];
    [request addValue:[self userAgentString] forHTTPHeaderField:@"User-Agent"];
    data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&err];
    if (err)
    {
        NSLog(@"Attempting to load %@ produced an NSURLConnection-level error (%@)", description, err);
    }
    else if ([response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse *)response).statusCode != 200)
    {
        // Tile 404's can happen a lot, so don't clutter the log with them, but do log things which aren't tile 404's.
        //
        if (! ([@"Tile" isEqualToString:description] && ((NSHTTPURLResponse *)response).statusCode == 404))
        {
            NSLog(@"Attempting to load %@ failed by receiving an HTTP status %li", description, (long)((NSHTTPURLResponse *)response).statusCode);
        }

        // On the other hand, return an appropriate NSError for any HTTP response other than 200.
        //
        NSString *errorReason = [NSString stringWithFormat:@"HTTP status %li was received", (long)((NSHTTPURLResponse *)response).statusCode];

        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey        : NSLocalizedString(@"HTTP status error", nil),
                                    NSLocalizedFailureReasonErrorKey : NSLocalizedString(errorReason, nil) };

        err = [NSError errorWithDomain:MBXMapKitErrorDomain code:MBXMapKitErrorCodeHTTPStatus userInfo:userInfo];

        [[NSNotificationCenter defaultCenter] postNotificationName:MBXNotificationHTTPFailure object:self];
    }
    else
    {
        // Reaching this point means we should have received a successful HTTP request
        //
        [[NSNotificationCenter defaultCenter] postNotificationName:MBXNotificationHTTPSuccess object:self];
    }

    // De-refrencing a null pointer is bad, so make sure we don't do that.
    //
    if(error)
    {
        *error = err;
    }
    return data;
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


- (NSString *)userAgentString
{
#if TARGET_OS_IPHONE
    return [NSString stringWithFormat:@"MBXMapKit (%@/%@)", [[UIDevice currentDevice] model], [[UIDevice currentDevice] systemVersion]];
#else
    return [NSString stringWithFormat:@"MBXMapKit (OS X/%@)", [[NSProcessInfo processInfo] operatingSystemVersionString]];
#endif
}


@end
