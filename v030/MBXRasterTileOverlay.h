//
//  MBXRasterTileOverlay.h
//  MBXMapKit
//
//  Created by Will Snook on 3/2/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import <MapKit/MapKit.h>

@class MBXRasterTileOverlay;
@class MBXOfflineMapDatabase;

#pragma mark - Image quality constants

typedef NS_ENUM(NSUInteger, MBXRasterImageQuality) {
    MBXRasterImageQualityFull = 0,   // default
    MBXRasterImageQualityPNG32 = 1,  // 32 color indexed PNG
    MBXRasterImageQualityPNG64 = 2,  // 64 color indexed PNG
    MBXRasterImageQualityPNG128 = 3, // 128 color indexed PNG
    MBXRasterImageQualityPNG256 = 4, // 256 color indexed PNG
    MBXRasterImageQualityJPEG70 = 5, // 70% quality JPEG
    MBXRasterImageQualityJPEG80 = 6, // 80% quality JPEG
    MBXRasterImageQualityJPEG90 = 7  // 90% quality JPEG
};


#pragma mark - Constants for the MBXMapKit error domain

extern NSString *const MBXMapKitErrorDomain;
extern NSInteger const MBXMapKitErrorCodeHTTPStatus;
extern NSInteger const MBXMapKitErrorCodeDictionaryMissingKeys;


#pragma mark - Delegate callbacks for asynchronous loading of map metadata and markers

@protocol MBXRasterTileOverlayDelegate <NSObject>

- (void)tileOverlay:(MBXRasterTileOverlay *)overlay didLoadMetadata:(NSDictionary *)metadata withError:(NSError *)error;
- (void)tileOverlay:(MBXRasterTileOverlay *)overlay didLoadMarkers:(NSArray *)markers withError:(NSError *)error;
- (void)tileOverlayDidFinishLoadingMetadataAndMarkersForOverlay:(MBXRasterTileOverlay *)overlay;

@end


#pragma mark -

@interface MBXRasterTileOverlay : MKTileOverlay

#pragma mark - Tile url utility funtions

+ (NSString *)qualityExtensionForImageQuality:(MBXRasterImageQuality)imageQuality;


#pragma mark - Map tile overlay layer initialization and configuration

- (id)initWithMapID:(NSString *)mapID;
- (id)initWithMapID:(NSString *)mapID metadata:(BOOL)metadata markers:(BOOL)markers;
- (id)initWithMapID:(NSString *)mapID metadata:(BOOL)metadata markers:(BOOL)markers imageQuality:(MBXRasterImageQuality)imageQuality;
- (id)initWithOfflineMapDatabase:(MBXOfflineMapDatabase *)offlineMapDatabase delegate:(id<MBXRasterTileOverlayDelegate>)delegate;

@property (weak,nonatomic) id<MBXRasterTileOverlayDelegate> delegate;

- (void)invalidateAndCancel;


#pragma mark - Read-only properties to check initialized values

@property (readonly,nonatomic) NSString *mapID;
@property (readonly,nonatomic) CLLocationCoordinate2D center;
@property (readonly,nonatomic) NSInteger centerZoom;
@property (readonly,nonatomic) NSArray *markers;


#pragma mark - Methods for invalidating cached metadata and markers

- (void)clearCachedMetadata;
- (void)clearCachedMarkers;


@end
