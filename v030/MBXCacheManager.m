//
//  MBXCacheManager.m
//  MBXMapKit
//
//  Created by Will Snook on 3/2/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXCacheManager.h"

@implementation MBXCacheManager

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
    *error = nil;
    return nil;
}

- (NSData *)proxySimplestyleForMapID:(NSString *)mapID withError:(NSError **)error
{
    *error = nil;
    return nil;
}

- (NSData *)proxyTileAtPath:(MKTileOverlayPath)path forMapID:(NSString *)mapID withError:(NSError **)error
{
    *error = nil;
    return nil;
}

- (NSData *)proxyMarkerIcon:(NSString *)markerFilename withError:(NSError **)error
{
    *error = nil;
    return nil;
}


#pragma mark - Methods for invalidating portions of the cache

- (void)invalidateMapID:(NSString *)mapID
{

}

- (void)invalidateTileJSONForMapID:(NSString *)mapID
{

}

- (void)invalidateSimplestyleForMapID:(NSString *)mapID
{

}

- (void)invalidateMarkerIcons
{

}

- (void)invalidateTheEntireCache
{

}



@end
