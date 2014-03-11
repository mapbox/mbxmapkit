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

typedef NS_ENUM(NSUInteger, MBXRasterImageQuality) {
    MBXRasterImageQualityFull,   // default
    MBXRasterImageQualityPNG32,  // 32 color indexed PNG
    MBXRasterImageQualityPNG64,  // 64 color indexed PNG
    MBXRasterImageQualityPNG128, // 128 color indexed PNG
    MBXRasterImageQualityPNG256, // 256 color indexed PNG
    MBXRasterImageQualityJPEG70, // 70% quality JPEG
    MBXRasterImageQualityJPEG80, // 80% quality JPEG
    MBXRasterImageQualityJPEG90  // 90% quality JPEG
};


#pragma mark - Methods for proxying resources through the cache

- (NSData *)proxyTileJSONForMapID:(NSString *)mapID withError:(NSError **)error;

- (NSData *)proxySimplestyleForMapID:(NSString *)mapID withError:(NSError **)error;

- (NSData *)proxyTileAtPath:(MKTileOverlayPath)path forMapID:(NSString *)mapID withQuality:(MBXRasterImageQuality)imageQuality withError:(NSError **)error;

- (NSData *)proxyMarkerIconSize:(NSString *)size symbol:(NSString *)symbol color:(NSString *)color error:(NSError **)error;


#pragma mark - Methods for invalidating portions of the cache

- (void)clearMapID:(NSString *)mapID;

- (void)clearSimplestyleForMapID:(NSString *)mapID;

- (void)clearMarkerIcons;

- (void)clearEntireCache;

@end
