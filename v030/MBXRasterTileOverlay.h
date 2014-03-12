//
//  MBXRasterTileOverlay.h
//  MBXMapKit
//
//  Created by Will Snook on 3/2/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import <MapKit/MapKit.h>
#import "MBXPointAnnotation.h"

@class MBXRasterTileOverlay;

#pragma mark - Image quality constants

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


#pragma mark - Notification strings for cache and network statistics

extern NSString * const MBXNotificationTypeCacheHit;
extern NSString * const MBXNotificationTypeHTTPSuccess;
extern NSString * const MBXNotificationTypeHTTPFailure;
extern NSString * const MBXNotificationTypeNetworkFailure;
extern NSString * const MBXNotificationUserInfoKeyError;


#pragma mark - Constants for the MBXMapKit error domain

extern NSString *const MBXMapKitErrorDomain;
extern NSInteger const MBXMapKitErrorCodeHTTPStatus;
extern NSInteger const MBXMapKitErrorCodeDictionaryMissingKeys;


#pragma mark - Delegate callbacks for asynchronous loading of map metadata and markers

@protocol MBXRasterTileOverlayDelegate <NSObject>
@optional

- (void)MBXRasterTileOverlay:(MBXRasterTileOverlay *)overlay didLoadMetadata:(NSDictionary *)metadata;
- (void)MBXRasterTileOverlay:(MBXRasterTileOverlay *)overlay didLoadMarker:(MBXPointAnnotation *)marker;
- (void)MBXRasterTileOverlay:(MBXRasterTileOverlay *)overlay didFailLoadingMetadataWithError:(NSError *)error;
- (void)MBXRasterTileOverlay:(MBXRasterTileOverlay *)overlay didFailLoadingMarkersWithError:(NSError *)error;

@end


#pragma mark -

@interface MBXRasterTileOverlay : MKTileOverlay


#pragma mark - Map tile overlay layer initialization and configuration

- (id)initWithMapID:(NSString *)mapID;
- (id)initWithMapID:(NSString *)mapID loadMetadata:(BOOL)loadMetadata loadMarkers:(BOOL)loadMarkers;
- (id)initWithMapID:(NSString *)mapID loadMetadata:(BOOL)loadMetadata loadMarkers:(BOOL)loadMarkers imageQuality:(MBXRasterImageQuality)imageQuality;

@property (weak,nonatomic) id<MBXRasterTileOverlayDelegate> delegate;


#pragma mark - Read-only properties to check initialized values

@property (readonly,nonatomic) NSString *mapID;
@property (readonly,nonatomic) CLLocationCoordinate2D center;
@property (readonly,nonatomic) NSInteger centerZoom;


#pragma mark - Methods for invalidating cached metadata and markers

- (void)clearCachedMetadata;
- (void)clearCachedMarkers;


@end
