//
//  MBXCacheManager.m
//  MBXMapKit
//
//  Created by Will Snook on 3/2/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXCacheManager.h"

@interface MBXCacheManager ()

@property (nonatomic) NSString *cachePath;

@end


@implementation MBXCacheManager

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

- (void)prepareCacheForMapID:(NSString *)mapID
{
    // Make sure the necessary cache directories are in place
    //
    NSString *path = [NSString stringWithFormat:@"%@/%@", self.cachePath, mapID];
    NSError *error;

    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
    if (error && error.code != NSFileWriteFileExistsError)
    {
        // NSFileWriteFileExistsError is fine because it just means the directory already existed, but other errors are bad.
        //
        NSLog(@"There was an error creating a cache directory - (%@)",error);
    }

    path = [NSString stringWithFormat:@"%@/markers", self.cachePath];
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
    if (error && error.code != NSFileWriteFileExistsError)
    {
        NSLog(@"There was an error creating a cache directory - (%@)",error);
    }
}


- (NSData *)proxyTileJSONForMapID:(NSString *)mapID withError:(NSError **)error
{
    // Attempt to fetch some TileJSON from the cache if it's available, or by downloading it if not
    //
    return [self proxyResourceDescription:@"TileJSON"
                        relativeCachePath:[NSString stringWithFormat:@"%@/%@.json", mapID, mapID]
                                urlString:[NSString stringWithFormat:@"https://a.tiles.mapbox.com/v3/%@.json", mapID]
                                    error:error
            ];
}


- (NSData *)proxySimplestyleForMapID:(NSString *)mapID withError:(NSError **)error
{
    // Attempt to fetch some simplestyle from the cache if it's available, or by downloading it if not
    //
    return [self proxyResourceDescription:@"Simplestyle"
                        relativeCachePath:[NSString stringWithFormat:@"%@/markers.json", mapID]
                                urlString:[NSString stringWithFormat:@"https://a.tiles.mapbox.com/v3/%@/markers.geojson", mapID]
                                    error:error
            ];
}


- (NSData *)proxyTileAtPath:(MKTileOverlayPath)path forMapID:(NSString *)mapID withQuality:(MBXRasterImageQuality)imageQuality withError:(NSError **)error
{
    // Attempt to fetch a tile from the cache if it's available, or by downloading it if not
    //
    NSString *cachePath = [NSString stringWithFormat:@"%@/%ld_%ld_%ld%@.%@",
                           mapID,
                           (long)path.z,
                           (long)path.x,
                           (long)path.y,
                           (path.contentScaleFactor > 1.0 ? @"@2x" : @""),
                           [self qualityExtensionForImageQuality:imageQuality]
                           ];

    NSString *urlString = [NSString stringWithFormat:@"https://a.tiles.mapbox.com/v3/%@/%ld/%ld/%ld%@.%@",
                           mapID,
                           (long)path.z,
                           (long)path.x,
                           (long)path.y,
                           (path.contentScaleFactor > 1.0 ? @"@2x" : @""),
                           [self qualityExtensionForImageQuality:imageQuality]
                           ];

    return [self proxyResourceDescription:@"Tile"
                        relativeCachePath:cachePath
                                urlString:urlString
                                    error:error
            ];
}


- (NSData *)proxyMarkerIcon:(NSString *)markerFilename withError:(NSError **)error
{
    // Attempt to fetch a marker icon from the cache if it's available, or by downloading it if not
    //
    return [self proxyResourceDescription:@"Marker icon"
                        relativeCachePath:[NSString stringWithFormat:@"markers/%@", markerFilename]
                                urlString:[NSString stringWithFormat:@"https://a.tiles.mapbox.com/v3/marker/%@", markerFilename]
                                    error:error
            ];
}


#pragma mark - Methods for invalidating portions of the cache

- (void)clearMapID:(NSString *)mapID
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(void)
    {
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", [self cachePath], mapID] error:nil];
    });
}


- (void)clearSimplestyleForMapID:(NSString *)mapID
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(void)
    {
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@/markers.geojson", [self cachePath], mapID] error:nil];
    });
}


- (void)clearMarkerIcons
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(void)
    {
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/markers", [self cachePath]] error:nil];
    });
}


- (void)clearEntireCache
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(void)
    {
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@", [self cachePath]] error:nil];
    });
}


- (void)sweepCache
{
    NSDirectoryEnumerator *cacheEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:[self  cachePath]];
    NSString *filename;

    while ((filename = [cacheEnumerator nextObject]))
    {
        NSString *filePath = [NSString stringWithFormat:@"%@/%@", [self cachePath], filename];
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];

        if (attributes[NSFileType] == NSFileTypeRegular && [[NSDate date] timeIntervalSinceDate:attributes[NSFileModificationDate]] < _cacheInterval)
        {
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
            NSLog(@"removing %@",filePath);
        }
        else
        {
            // Clean up any empty cache files that might be lying around from previous bugs
            //
            if ((attributes[NSFileType] == NSFileTypeRegular) && ([attributes[NSFileSize] integerValue] == 0))
                [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        }
    }
}




#pragma mark - Private implementation methods

- (NSData *)proxyResourceDescription:(NSString *)description relativeCachePath:(NSString *)relativeCachePath urlString:(NSString *)urlString error:(NSError **)error
{
    // Make the point that we had better not be blocking the main thread here
    //
    assert(![NSThread isMainThread]);

    // Determine if this is a cache hit. If so, request the file from cache. Otherwise, request the file by HTTP.
    //
    NSString *resourceCachePath = [NSString stringWithFormat:@"%@/%@", self.cachePath, relativeCachePath];
    NSURL *url;

    if ([[NSFileManager defaultManager] fileExistsAtPath:resourceCachePath])
    {
        url = [NSURL fileURLWithPath:resourceCachePath];
    }
    else
    {
        url = [NSURL URLWithString:urlString];
    }

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
    }
    else
    {
        // At this point we should have an NSHTTPURLResponse with an HTTP 200, or else an
        // NSURLResponse with the contents of a file from cache. Both of those are good.
        // Cache the tileJSON only if it came from an HTTP 200 response.
        //
        if ([response isKindOfClass:[NSHTTPURLResponse class]])
        {
            [data writeToFile:resourceCachePath atomically:YES];
        }
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


- (NSString *)cachePath
{
    if ( ! _cachePath)
        _cachePath = [NSString stringWithFormat:@"%@/%@", [self systemPath], kMBXMapViewCacheFolder];

    return _cachePath;
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


@end
