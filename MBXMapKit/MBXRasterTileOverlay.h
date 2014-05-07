//
//  MBXRasterTileOverlay.h
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

#import <MapKit/MapKit.h>
#import "MBXConstantsAndTypes.h"

@class MBXRasterTileOverlay;
@class MBXOfflineMapDatabase;


#pragma mark - Constants for the MBXMapKit error domain

extern NSString *const MBXMapKitErrorDomain;
extern NSInteger const MBXMapKitErrorCodeHTTPStatus;
extern NSInteger const MBXMapKitErrorCodeDictionaryMissingKeys;


#pragma mark - Delegate callbacks for asynchronous loading of map metadata and markers

@protocol MBXRasterTileOverlayDelegate <NSObject>

- (void)tileOverlay:(MBXRasterTileOverlay *)overlay didLoadMetadata:(NSDictionary *)metadata withError:(NSError *)error;
- (void)tileOverlay:(MBXRasterTileOverlay *)overlay didLoadMarkers:(NSArray *)markers withError:(NSError *)error;
- (void)tileOverlayDidFinishLoadingMetadataAndMarkers:(MBXRasterTileOverlay *)overlay;

@end


#pragma mark -

@interface MBXRasterTileOverlay : MKTileOverlay


#pragma mark - Map tile overlay layer initialization and configuration

- (id)initWithMapID:(NSString *)mapID;
- (id)initWithMapID:(NSString *)mapID includeMetadata:(BOOL)includeMetadata includeMarkers:(BOOL)includeMarkers;
- (id)initWithMapID:(NSString *)mapID includeMetadata:(BOOL)includeMetadata includeMarkers:(BOOL)includeMarkers imageQuality:(MBXRasterImageQuality)imageQuality;
- (id)initWithOfflineMapDatabase:(MBXOfflineMapDatabase *)offlineMapDatabase;

@property (weak,nonatomic) id<MBXRasterTileOverlayDelegate> delegate;

- (void)invalidateAndCancel;


#pragma mark - Read-only properties to check initialized values

@property (readonly,nonatomic) NSString *mapID;
@property (readonly,nonatomic) CLLocationCoordinate2D center;
@property (readonly,nonatomic) NSInteger centerZoom;
@property (readonly,nonatomic) NSArray *markers;
@property (readonly,nonatomic) NSString *attribution;


#pragma mark - Methods for invalidating cached metadata and markers

- (void)clearCachedMetadata;
- (void)clearCachedMarkers;


@end
