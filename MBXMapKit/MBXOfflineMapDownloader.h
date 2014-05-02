//
//  MBXOfflineMapDownloader.h
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//


#pragma mark - Task states

typedef NS_ENUM(NSUInteger, MBXOfflineMapDownloaderState) {
    MBXOfflineMapDownloaderStateRunning,
    MBXOfflineMapDownloaderStateSuspended,
    MBXOfflineMapDownloaderStateCanceling,
    MBXOfflineMapDownloaderStateAvailable
};


#pragma mark - Delegate protocol for progress updates

@class MBXOfflineMapDownloader;
@class MBXOfflineMapDatabase;

@protocol MBXOfflineMapDownloaderDelegate <NSObject>

- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader stateChangedTo:(MBXOfflineMapDownloaderState)state;

- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader totalFilesExpectedToWrite:(NSUInteger)totalFilesExpectedToWrite;

- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader totalFilesWritten:(NSUInteger)totalFilesWritten totalFilesExpectedToWrite:(NSUInteger)totalFilesExpectedToWrite;

- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader didEncounterRecoverableError:(NSError *)error;

- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader didCompleteOfflineMapDatabase:(MBXOfflineMapDatabase *)offlineMapDatabase withError:(NSError *)error;

@end


#pragma mark -

@interface MBXOfflineMapDownloader : NSObject


#pragma mark -

+ (MBXOfflineMapDownloader *)sharedOfflineMapDownloader;


#pragma mark -

@property (readonly, nonatomic) NSString *mapID;
@property (readonly, nonatomic) BOOL includesMetadata;
@property (readonly, nonatomic) BOOL includesMarkers;
@property (readonly, nonatomic) MBXRasterImageQuality imageQuality;
@property (readonly, nonatomic) MKCoordinateRegion mapRegion;
@property (readonly, nonatomic) NSInteger minimumZ;
@property (readonly, nonatomic) NSInteger maximumZ;
@property (readonly, nonatomic) MBXOfflineMapDownloaderState state;

@property (readonly, nonatomic) NSArray *offlineMapDatabases;

@property (readonly,nonatomic) NSUInteger totalFilesWritten;
@property (readonly,nonatomic) NSUInteger totalFilesExpectedToWrite;

@property (nonatomic) id<MBXOfflineMapDownloaderDelegate> delegate;

@property (nonatomic) BOOL offlineMapsAreExcludedFromBackup;


#pragma mark -

- (void)beginDownloadingMapID:(NSString *)mapID mapRegion:(MKCoordinateRegion)mapRegion minimumZ:(NSInteger)minimumZ maximumZ:(NSInteger)maximumZ;

- (void)beginDownloadingMapID:(NSString *)mapID mapRegion:(MKCoordinateRegion)mapRegion minimumZ:(NSInteger)minimumZ maximumZ:(NSInteger)maximumZ includeMetadata:(BOOL)includeMetadata includeMarkers:(BOOL)includeMarkers ;

- (void)beginDownloadingMapID:(NSString *)mapID mapRegion:(MKCoordinateRegion)mapRegion minimumZ:(NSInteger)minimumZ maximumZ:(NSInteger)maximumZ includeMetadata:(BOOL)includeMetadata includeMarkers:(BOOL)includeMarkers imageQuality:(MBXRasterImageQuality)imageQuality;

- (void)cancel;
- (void)resume;
- (void)suspend;

- (void)removeOfflineMapDatabase:(MBXOfflineMapDatabase *)offlineMapDatabase;

@end
