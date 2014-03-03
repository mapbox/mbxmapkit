//
//  MBXCacheManagerProtocol.h
//  MBXMapKit
//
//  Created by Will Snook on 3/2/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@protocol MBXCacheManagerProtocol <NSObject>


#pragma mark - Methods for proxying resources through the cache

- (NSData *)proxyTileJSONForMapID:(NSString *)mapID withError:(NSError **)error;

- (NSData *)proxySimplestyleForMapID:(NSString *)mapID withError:(NSError **)error;

- (NSData *)proxyTileAtPath:(MKTileOverlayPath)path forMapID:(NSString *)mapID withError:(NSError **)error;

- (NSData *)proxyMarkerIcon:(NSString *)markerFilename withError:(NSError **)error;


#pragma mark - Methods for invalidating portions of the cache

- (void)invalidateMapID:(NSString *)mapID;

- (void)invalidateTileJSONForMapID:(NSString *)mapID;

- (void)invalidateSimplestyleForMapID:(NSString *)mapID;

- (void)invalidateMarkerIcons;

- (void)invalidateTheEntireCache;


@end
