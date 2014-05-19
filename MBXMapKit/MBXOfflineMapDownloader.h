//
//  MBXOfflineMapDownloader.h
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//


#pragma mark - Task states

/** The four possible states of the offline map downloader state machine */
typedef NS_ENUM(NSUInteger, MBXOfflineMapDownloaderState) {
    /** An offline map download job is in progress */
    MBXOfflineMapDownloaderStateRunning,
    /** An offline map download job is suspended and can be either resumed or canceled */
    MBXOfflineMapDownloaderStateSuspended,
    /** An offline map download job is being canceled */
    MBXOfflineMapDownloaderStateCanceling,
    /** The offline map downloader is ready to begin a new offline map download job */
    MBXOfflineMapDownloaderStateAvailable
};


#pragma mark - Delegate protocol for progress updates

@class MBXOfflineMapDownloader;
@class MBXOfflineMapDatabase;

/** Provides notifications of download progress and state machine transitions for the offline map downloader */
@protocol MBXOfflineMapDownloaderDelegate <NSObject>

/** Notification that the offline map downloader's state has changed. This is designed to facilitate UI updates such as enabling and disabling buttons and network activity indicators.
 @param offlineMapDownloader The offline map downloader providing the notification
 @param state The new state
 */
- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader stateChangedTo:(MBXOfflineMapDownloaderState)state;

/** Notification of the number of resources which will be requested as part of the current offline map download job. This is designed to facilitate a UI update to show a progress indicator, and to enable sanity checks for whether the number of tiles being requested is reasonable.
 @param offlineMapDownloader The offline map downloader providing the notification
 @param totalFilesExpectedToWrite The initial estimate of how many resources will be downloaded. This is primarily determined from the map region and zoom limits which were used to begin a download job, but it also potentially includes JSON and marker icons.
 @warning Since the offline map downloader does not impose any arbitrary upper limit on the number of tiles which may be requested from the Mapbox API, it is possible to request a very large amount of data. You might want to provide your own checks or accounting mechanisms to manage the number of tiles your apps request from the API.
 */
- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader totalFilesExpectedToWrite:(NSUInteger)totalFilesExpectedToWrite;

/** Notification for calculating the percentage completion of an offline map download job. This is designed to facilitate updating a progress indicator.
 @param offlineMapDownloader The offline map downloader providing the notification
 @param totalFilesWritten The number of files which have been downloaded and saved to the database on disk.
 @param totalFilesExpectedToWrite The initial estimate of how many resources will be downloaded. This is primarily determined from the map region and zoom limits which were used to begin a download job, but it also potentially includes JSON and marker icons.
 */
- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader totalFilesWritten:(NSUInteger)totalFilesWritten totalFilesExpectedToWrite:(NSUInteger)totalFilesExpectedToWrite;

/** Notification that something unexpected, but not necessarily bad, has happened. This is designed to provide an opportunity to recognize potential configuration problems with your map. For example, you might get 404's for a custom regional map if you request a map region which extends outside of your map data's coverage area. Depending on the application, the 404's could indicate a problem with the coverage area, or they might be irrelevant.
 @param offlineMapDownloader The offline map downloader providing the notification
 */
- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader didEncounterRecoverableError:(NSError *)error;

/** Notification that an offline map download job has finished, either successfully (`error == nil`), or with a non-recoverable error (`error != nil`).
 @param offlineMapDownloader The offline map downloader providing the notification
 @param offlineMapDatabase An offline map database object which you can use to create an MBXRasterTileOverlay. This may be `nil` if there was an error.
 @param error The nature of the error which stopped the offline map download job. For successful completion, this will be `nil`.
 */
- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader didCompleteOfflineMapDatabase:(MBXOfflineMapDatabase *)offlineMapDatabase withError:(NSError *)error;

@end


#pragma mark -

/** A class for managing the downloading of offline maps. Note that this is meant to be accessed with the shared singleton, sharedOfflineMapDownloader */
@interface MBXOfflineMapDownloader : NSObject


#pragma mark -

/** The shared offline map downloader */
+ (MBXOfflineMapDownloader *)sharedOfflineMapDownloader;


#pragma mark -

/** The offline map downloader's current state */
@property (readonly, nonatomic) MBXOfflineMapDownloaderState state;

/** If a download job is running or suspended, the map ID which was used to begin that job. */
@property (readonly, nonatomic) NSString *mapID;
/** If a download job is running or suspended, whether the job was specified to include metadata */
@property (readonly, nonatomic) BOOL includesMetadata;
/** If a download job is running or suspended, whether the job was specified to include markers */
@property (readonly, nonatomic) BOOL includesMarkers;
/** If a download job is running or suspended, the image quality which was specified for downloading the job's tiles */
@property (readonly, nonatomic) MBXRasterImageQuality imageQuality;
/** If a download job is running or suspended, the map region which was specified to begin the job */
@property (readonly, nonatomic) MKCoordinateRegion mapRegion;
/** If a download job is running or suspended, the minimum zoom which was specified to begin the job */
@property (readonly, nonatomic) NSInteger minimumZ;
/** If a download job is running or suspended, the maximum zoom which was specified to begin the job */
@property (readonly, nonatomic) NSInteger maximumZ;
/** If a download job is running or suspended, the number of files which have been written */
@property (readonly,nonatomic) NSUInteger totalFilesWritten;
/** If a download job is running or suspended, the number of files which need to be written to finish the job */
@property (readonly,nonatomic) NSUInteger totalFilesExpectedToWrite;


/** An array of instantiated MBXOfflineMapDatabases representing all completed offline map databases on disk. This is designed, in combination with the properties provided by MBXOfflineMapDatabase, to let you enumerate and manage the maps which are available on disk. */
@property (readonly, nonatomic) NSArray *offlineMapDatabases;

/** Whether offline map databases should be excluded from iCloud and iTunes backups. This defaults to YES, and if you want to make a change, the value will persist across app re-launches since it changes the offline map folder's resource value on disk.  */
@property (nonatomic) BOOL offlineMapsAreExcludedFromBackup;

/** The delegate which should receive notifications as the offline map downloader's state and progress change */
@property (nonatomic) id<MBXOfflineMapDownloaderDelegate> delegate;

/** This is initially populated with MBXMapKit's default user agent, but you can set a custom value to use your own user agent string */
@property (nonatomic) NSString *userAgent;


#pragma mark -

/** Begin an offline map download job including metadata and markers, and using the default (full) image quality
 @param mapID The map ID to download offline map data from
 @param mapRegion The region of the map to download tiles for
 @param minimumZ The minimum zoom level to download tiles for
 @param maximumZ The maximum zoom level to download tiles for. Be careful with this as the number of tiles per zoom level increases exponentially!
 */
- (void)beginDownloadingMapID:(NSString *)mapID mapRegion:(MKCoordinateRegion)mapRegion minimumZ:(NSInteger)minimumZ maximumZ:(NSInteger)maximumZ;

/** Begin an offline map download job using the default (full) image quality
 @param mapID The map ID to download offline map data from
 @param mapRegion The region of the map to download tiles for
 @param minimumZ The minimum zoom level to download tiles for
 @param maximumZ The maximum zoom level to download tiles for. Be careful with this as the number of tiles per zoom level increases exponentially!
 @param includeMetadata Whether to include the map's metadata (for initial center point and zoom, etc) in the offline map
 @param includeMarkers Whether to include the map's markers in the offline map
 */
- (void)beginDownloadingMapID:(NSString *)mapID mapRegion:(MKCoordinateRegion)mapRegion minimumZ:(NSInteger)minimumZ maximumZ:(NSInteger)maximumZ includeMetadata:(BOOL)includeMetadata includeMarkers:(BOOL)includeMarkers ;

/** Begin an offline map download job
 @param mapID The map ID to download offline map data from
 @param mapRegion The region of the map to download tiles for
 @param minimumZ The minimum zoom level to download tiles for
 @param maximumZ The maximum zoom level to download tiles for. Be careful with this as the number of tiles per zoom level increases exponentially!
 @param includeMetadata Whether to include the map's metadata (for initial center point and zoom, etc) in the offline map
 @param includeMarkers Whether to include the map's markers in the offline map
 @param imageQuality Which image quality to use for requesting tiles
 */
- (void)beginDownloadingMapID:(NSString *)mapID mapRegion:(MKCoordinateRegion)mapRegion minimumZ:(NSInteger)minimumZ maximumZ:(NSInteger)maximumZ includeMetadata:(BOOL)includeMetadata includeMarkers:(BOOL)includeMarkers imageQuality:(MBXRasterImageQuality)imageQuality;

/** Cancel the current offline map download job, discarding any resources which have been saved */
- (void)cancel;

/** Resume a previously suspended offline map download job */
- (void)resume;

/** Suspend a currently running offline map download job */
- (void)suspend;

/** Invalidate an offline map object and remove its associated backing database on disk. This is designed for managing the disk storage consumed by offline maps. */
- (void)removeOfflineMapDatabase:(MBXOfflineMapDatabase *)offlineMapDatabase;

@end
