//
//  MBXOfflineMapDownloader.h
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

@import Foundation;
@import MapKit;

#pragma mark - Task states

/** The possible states of the offline map downloader. */
typedef NS_ENUM(NSUInteger, MBXOfflineMapDownloaderState) {
    /** An offline map download job is in progress. */
    MBXOfflineMapDownloaderStateRunning,
    /** An offline map download job is suspended and can be either resumed or canceled. */
    MBXOfflineMapDownloaderStateSuspended,
    /** An offline map download job is being canceled. */
    MBXOfflineMapDownloaderStateCanceling,
    /** The offline map downloader is ready to begin a new offline map download job. */
    MBXOfflineMapDownloaderStateAvailable
};


#pragma mark - Delegate protocol for progress updates

@class MBXOfflineMapDownloader;
@class MBXOfflineMapDatabase;

/** The `MBXOfflineMapDownloaderDelegate` protocol provides notifications of download progress and state machine transitions for the shared offline map downloader. */
@protocol MBXOfflineMapDownloaderDelegate <NSObject>

@optional

/** @name Observing Changes to the Downloader's State */

/** Notifies the delegate that the offline map downloader's state has changed. This is designed to facilitate user interface updates such as enabling and disabling buttons and network activity indicators.
*   @param offlineMapDownloader The offline map downloader whose state has changed.
*   @param state The new state of the downloader. */
- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader stateChangedTo:(MBXOfflineMapDownloaderState)state;

/** @name Obtaining Information About Download Jobs */

/** Notifies the delegate of the number of resources which will be requested as part of the current offline map download job. This is designed to facilitate a user interface update to show a progress indicator, as well as to enable sanity checks for whether the number of tiles being requested is reasonable.
*   @param offlineMapDownloader The offline map downloader whose state has changed.
*   @param totalFilesExpectedToWrite An estimated count of the number of resources that will be downloaded. This is primarily determined from the map region and zoom limits which were used to begin a download job, but it also potentially includes JSON and marker icon resources.
*
*   @warning Since the offline map downloader does not impose any arbitrary upper limit on the number of resources which may be requested from the Mapbox APIs, it is possible to request a very large amount of data. You might want to provide your own checks or accounting mechanisms to manage the number of resources that your apps request from the API. */
- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader totalFilesExpectedToWrite:(NSUInteger)totalFilesExpectedToWrite;

/** Notifies the delegate of changes to the percentage completion of an offline map download job. This is designed to facilitate updating a progress indicator.
*   @param offlineMapDownloader The offline map downloader.
*   @param totalFilesWritten The number of files which have been downloaded and saved to the database on disk.
*   @param totalFilesExpectedToWrite An estimated count of the number of resources that will be downloaded. This is primarily determined from the map region and zoom limits which were used to begin a download job, but it also potentially includes JSON and marker icon resources. */
- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader totalFilesWritten:(NSUInteger)totalFilesWritten totalFilesExpectedToWrite:(NSUInteger)totalFilesExpectedToWrite;

/** @name Ending Download Jobs */

/** Notifies the delegate that something unexpected, but not necessarily bad, has happened. This is designed to provide an opportunity to recognize potential configuration problems with your map. For example, you might receive an HTTP 404 response for a map tile if you request a map region which extends outside of your map data's coverage area. 
*   @param offlineMapDownloader The offline map downloader. 
*   @param error The error encountered. */
- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader didEncounterRecoverableError:(NSError *)error;

/** Notifies the delegate that an offline map download job has finished.
*
*   If the error parameter is `nil`, the job completed successfully. Otherwise, a non-recoverable error was encountered. 
*   @param offlineMapDownloader The offline map downloader which finished a job.
*   @param offlineMapDatabase An offline map database which you can use to create an `MBXRasterTileOverlay`. This paramtere may be `nil` if there was an error.
*   @param error The error which stopped the offline map download job. For successful completion, this parameter will be `nil`. */
- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader didCompleteOfflineMapDatabase:(MBXOfflineMapDatabase *)offlineMapDatabase withError:(NSError *)error;

@end


#pragma mark -

/** `MBXOfflineMapDownloader` is a class for managing the downloading of offline maps.
*
*   A single, shared instance of `MBXOfflineMapDownloader` exists and should be accessed with the `sharedOfflineMapDownloader` class method. */
@interface MBXOfflineMapDownloader : NSObject


#pragma mark -

/** @name Accessing the Shared Downloader */

/** Returns the shared offline map downloader. */
+ (MBXOfflineMapDownloader *)sharedOfflineMapDownloader;


#pragma mark -

/** @name Getting and Setting Attributes */

/** The offline map downloader's current state. */
@property (readonly, nonatomic) MBXOfflineMapDownloaderState state;

/** If a download job is running or suspended, the map ID which was used to begin that job. */
@property (readonly, nonatomic) NSString *mapID;

/** If a download job is running or suspended, whether the job was specified to include metadata. */
@property (readonly, nonatomic) BOOL includesMetadata;

/** If a download job is running or suspended, whether the job was specified to include markers. */
@property (readonly, nonatomic) BOOL includesMarkers;

/** If a download job is running or suspended, the image quality which was specified for downloading the job's map tiles. */
@property (readonly, nonatomic) MBXRasterImageQuality imageQuality;

/** If a download job is running or suspended, the map region which was specified to begin the job. */
@property (readonly, nonatomic) MKCoordinateRegion mapRegion;

/** If a download job is running or suspended, the minimum zoom which was specified to begin the job. */
@property (readonly, nonatomic) NSInteger minimumZ;

/** If a download job is running or suspended, the maximum zoom which was specified to begin the job. */
@property (readonly, nonatomic) NSInteger maximumZ;

/** If a download job is running or suspended, the number of files which have been written so far. */
@property (readonly,nonatomic) NSUInteger totalFilesWritten;

/** If a download job is running or suspended, the number of files which still need to be written to finish the job. */
@property (readonly,nonatomic) NSUInteger totalFilesExpectedToWrite;

/** An array of `MBXOfflineMapDatabase` objects representing all completed offline map databases on disk. This is designed, in combination with the properties provided by `MBXOfflineMapDatabase`, to allow enumeration and management of the maps which are available on disk. */
@property (readonly, nonatomic) NSArray *offlineMapDatabases;

/** Whether offline map databases should be excluded from iCloud and iTunes backups. This defaults to `YES`. If you want to make a change, the value will persist across app launches since it changes the offline map folder's resource value on disk. */
@property (nonatomic) BOOL offlineMapsAreExcludedFromBackup;

/** @name Managing the Delegate */

/** The delegate which should receive notifications as the offline map downloader's state and progress change. */
@property (nonatomic) id<MBXOfflineMapDownloaderDelegate> delegate;

#pragma mark -

/** @name Managing Active Download Jobs */

/** Begins an offline map download job including metadata and markers using the default (full) image quality.
*   @param mapID The map ID from which to download offline map data.
*   @param mapRegion The region of the map for which to download tiles.
*   @param minimumZ The minimum zoom level for which to download tiles.
*   @param maximumZ The maximum zoom level for which to download tiles. 
*
*   @warning It is recommended to check the return value of the offlineMapDownloader:totalFilesExpectedToWrite: delegate method to ensure that an unexpectedly large number of resources aren't going to be loaded. Map tile counts increase exponentially with increasing zoom level. */
- (void)beginDownloadingMapID:(NSString *)mapID mapRegion:(MKCoordinateRegion)mapRegion minimumZ:(NSInteger)minimumZ maximumZ:(NSInteger)maximumZ;

/** Begins an offline map download job using the default (full) image quality.
*   @param mapID The map ID from which to download offline map data.
*   @param mapRegion The region of the map for which to download tiles.
*   @param minimumZ The minimum zoom level for which to download tiles.
*   @param maximumZ The maximum zoom level for which to download tiles.
*   @param includeMetadata Whether to include the map's metadata (for values such as the initial center point and zoom) in the offline map.
*   @param includeMarkers Whether to include the map's marker image resources in the offline map.
*
*   @warning It is recommended to check the return value of the offlineMapDownloader:totalFilesExpectedToWrite: delegate method to ensure that an unexpectedly large number of resources aren't going to be loaded. Map tile counts increase exponentially with increasing zoom level. */
- (void)beginDownloadingMapID:(NSString *)mapID mapRegion:(MKCoordinateRegion)mapRegion minimumZ:(NSInteger)minimumZ maximumZ:(NSInteger)maximumZ includeMetadata:(BOOL)includeMetadata includeMarkers:(BOOL)includeMarkers;

/** Begins an offline map download job.
*   @param mapID The map ID from which to download offline map data.
*   @param mapRegion The region of the map for which to download tiles.
*   @param minimumZ The minimum zoom level for which to download tiles.
*   @param maximumZ The maximum zoom level for which to download tiles.
*   @param includeMetadata Whether to include the map's metadata (for values such as the initial center point and zoom) in the offline map.
*   @param includeMarkers Whether to include the map's marker image resources in the offline map.
*   @param imageQuality The image quality to when requesting tiles. */
- (void)beginDownloadingMapID:(NSString *)mapID mapRegion:(MKCoordinateRegion)mapRegion minimumZ:(NSInteger)minimumZ maximumZ:(NSInteger)maximumZ includeMetadata:(BOOL)includeMetadata includeMarkers:(BOOL)includeMarkers imageQuality:(MBXRasterImageQuality)imageQuality;

/** Cancels the current offline map download job and discards any associated resources. */
- (void)cancel;

/** Resumes a previously suspended offline map download job. */
- (void)resume;

/** Suspends a currently running offline map download job. */
- (void)suspend;

/** @name Removing Offline Maps */

/** Invalidates a given offline map and removes its associated backing database on disk. This is designed for managing the disk storage consumed by offline maps.
*   @param offlineMapDatabase The offline map database to invalidate. */
- (void)removeOfflineMapDatabase:(MBXOfflineMapDatabase *)offlineMapDatabase;

/** Invalidates the offline map with the given unique identifier and removes its associated backing database on disk. This is designed for managing the disk storage consumed by offline maps.
*   @param uniqueID The unique ID of the map database to invalidate. */
- (void)removeOfflineMapDatabaseWithID:(NSString *)uniqueID;

@end
