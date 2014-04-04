//
//  MBXOfflineMapDownloader.m
//  MBXMapKit
//
//  Created by Will Snook on 3/19/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import <sqlite3.h>
#import "MBXError.h"
#import "MBXOfflineMapDownloader.h"
#import "MBXOfflineMapDatabase.h"


#pragma mark -

@interface MBXOfflineMapDownloader ()

@property (readwrite, nonatomic) NSString *mapID;
@property (readwrite, nonatomic) BOOL metadata;
@property (readwrite, nonatomic) BOOL markers;
@property (readwrite, nonatomic) MBXRasterImageQuality imageQuality;
@property (readwrite, nonatomic) MKCoordinateRegion mapRegion;
@property (readwrite, nonatomic) NSInteger minimumZ;
@property (readwrite, nonatomic) NSInteger maximumZ;
@property (readwrite, nonatomic) MBXOfflineMapDownloaderState state;

@property (nonatomic) NSMutableArray *mutableOfflineMapDatabases;
@property (nonatomic) NSURL *offlineMapDirectory;

@property (nonatomic) id<MBXOfflineMapDownloaderDelegate> delegate;

@property (nonatomic) NSUInteger totalFilesWritten;
@property (nonatomic) NSUInteger totalFilesExpectedToWrite;

@property (nonatomic) NSTimer *fakeProgressTimer;

@end


#pragma mark -

@implementation MBXOfflineMapDownloader


#pragma mark - Shared downloader singleton

+ (MBXOfflineMapDownloader *)sharedOfflineMapDownloader
{
    static id _sharedDownloader = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _sharedDownloader = [[self alloc] init];
    });
    
    return _sharedDownloader;
}


#pragma mark -

- (NSArray *)offlineMapDatabases
{
    // Return an array with offline map database objects representing each of the *complete* map databases on disk
    //
    return [NSArray arrayWithArray:_mutableOfflineMapDatabases];
}


#pragma mark -

- (id)init
{
    self = [super init];

    if(self)
    {
        // Make sure the offline map directory exists and that it will be excluded from iCloud backups
        //
        NSFileManager *fm = [NSFileManager defaultManager];
        NSURL *appSupport = [fm URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
        _offlineMapDirectory = [appSupport URLByAppendingPathComponent:@"MBXMapKit/OfflineMaps"];
        if(_offlineMapDirectory)
        {
            NSError *error;
            BOOL result;
            result = [fm createDirectoryAtURL:_offlineMapDirectory withIntermediateDirectories:YES attributes:nil error:&error];
            [_offlineMapDirectory setResourceValues:@{NSURLIsExcludedFromBackupKey:@YES} error:nil];

            NSLog(@"\n%@\n%@",[_offlineMapDirectory absoluteString],[_offlineMapDirectory resourceValuesForKeys:@[NSURLIsExcludedFromBackupKey] error:nil]);
        }

        //
        // TODO: Restore persistent state from disk, or if the offline map directory doesn't exist, set up the directory.
        //
        _state = MBXOfflineMapDownloaderStateAvailable;
        _mutableOfflineMapDatabases = [[NSMutableArray alloc] init];
    }

    return self;
}

- (void)notifyDelegateOfStateChange
{
    if([_delegate respondsToSelector:@selector(offlineMapDownloader:stateChangedTo:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [_delegate offlineMapDownloader:self stateChangedTo:_state];
        });
    }
}


- (void)fakeProgressTimerAction:(NSTimer *)timer
{
    if(_totalFilesWritten <= _totalFilesExpectedToWrite)
    {
        // Do some fake work
        //
        _totalFilesWritten += 1;
    }

    // Notify the delegate about our fake progress
    //
    if([_delegate respondsToSelector:@selector(offlineMapDownloader:totalFilesWritten:totalFilesExpectedToWrite:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [_delegate offlineMapDownloader:self totalFilesWritten:_totalFilesWritten totalFilesExpectedToWrite:_totalFilesExpectedToWrite];
        });
    }

    if(_totalFilesWritten >= _totalFilesExpectedToWrite)
    {
        // Fake work is complete, so clean up and notify the delegate
        //
        [timer invalidate];

        if([_delegate respondsToSelector:@selector(offlineMapDownloader:didCompleteOfflineMapDatabase:withError:)])
        {
            MBXOfflineMapDatabase *mapDatabase = [[MBXOfflineMapDatabase alloc] init];
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [_delegate offlineMapDownloader:self didCompleteOfflineMapDatabase:mapDatabase withError:nil];
            });
        }

        _state = MBXOfflineMapDownloaderStateAvailable;
        [self notifyDelegateOfStateChange];
    }
}


- (void)beginDownloadingMapID:(NSString *)mapID mapRegion:(MKCoordinateRegion)mapRegion minimumZ:(NSInteger)minimumZ maximumZ:(NSInteger)maximumZ
{
    [self beginDownloadingMapID:mapID metadata:YES markers:YES imageQuality:MBXRasterImageQualityFull mapRegion:mapRegion minimumZ:minimumZ maximumZ:maximumZ];
}


- (void)beginDownloadingMapID:(NSString *)mapID metadata:(BOOL)metadata markers:(BOOL)markers mapRegion:(MKCoordinateRegion)mapRegion minimumZ:(NSInteger)minimumZ maximumZ:(NSInteger)maximumZ
{
    [self beginDownloadingMapID:mapID metadata:metadata markers:markers imageQuality:MBXRasterImageQualityFull mapRegion:mapRegion minimumZ:minimumZ maximumZ:maximumZ];
}


- (void)beginDownloadingMapID:(NSString *)mapID metadata:(BOOL)metadata markers:(BOOL)markers imageQuality:(MBXRasterImageQuality)imageQuality mapRegion:(MKCoordinateRegion)mapRegion minimumZ:(NSInteger)minimumZ maximumZ:(NSInteger)maximumZ
{
    assert(_state == MBXOfflineMapDownloaderStateAvailable);

    // Start a download job to retrieve all the resources needed for using the specified map offline
    //
    _mapID = mapID;
    _metadata = metadata;
    _markers = markers;
    _imageQuality = imageQuality;
    _mapRegion = mapRegion;
    _minimumZ = minimumZ;
    _maximumZ = maximumZ;
    _state = MBXOfflineMapDownloaderStateRunning;
    [self notifyDelegateOfStateChange];

    //
    // TODO: Make this real...
    //       - Calculate the list of tiles to be requested
    //       - Write all the URLS out to the sqlite with null data and a "needs to be downloaded" state
    //       - Start the thing which keeps track of the background downloads
    //

    // Fake like we're doing some work to facilitate testing the progress indicator GUI
    //
    _totalFilesExpectedToWrite = 100;
    _totalFilesWritten = 0;
    if([_delegate respondsToSelector:@selector(offlineMapDownloader:totalFilesExpectedToWrite:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [_delegate offlineMapDownloader:self totalFilesExpectedToWrite:_totalFilesExpectedToWrite];
        });
    }

    [_fakeProgressTimer invalidate];
    _fakeProgressTimer = [NSTimer scheduledTimerWithTimeInterval:0.314 target:self selector:@selector(fakeProgressTimerAction:) userInfo:nil repeats:YES];
}


- (void)cancel
{
    assert(_state == MBXOfflineMapDownloaderStateRunning || _state == MBXOfflineMapDownloaderStateSuspended);

    // Stop a download job and discard the associated files
    //
    _state = MBXOfflineMapDownloaderStateCanceling;
    [self notifyDelegateOfStateChange];

    // Stop the fake timer
    //
    [_fakeProgressTimer invalidate];

    // Notify the delegate
    //
    if([_delegate respondsToSelector:@selector(offlineMapDownloader:didCompleteOfflineMapDatabase:withError:)])
    {
        NSError *canceled = [MBXError errorWithCode:MBXMapKitErrorDownloadingCanceled reason:@"The download job was canceled" description:@"Download canceled"];
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [_delegate offlineMapDownloader:self didCompleteOfflineMapDatabase:nil withError:canceled];
        });
    }

    _state = MBXOfflineMapDownloaderStateAvailable;
    [self notifyDelegateOfStateChange];
}


- (void)resume
{
    assert(_state == MBXOfflineMapDownloaderStateSuspended);

    // Resume a previously suspended download job
    //
    [_fakeProgressTimer invalidate];
    _fakeProgressTimer = [NSTimer scheduledTimerWithTimeInterval:0.314 target:self selector:@selector(fakeProgressTimerAction:) userInfo:nil repeats:YES];

    _state = MBXOfflineMapDownloaderStateRunning;
    [self notifyDelegateOfStateChange];
}


- (void)suspend
{
    assert(_state == MBXOfflineMapDownloaderStateRunning);

    // Stop a download job and preserve the necessary state to resume later
    //
    [_fakeProgressTimer invalidate];
    _state = MBXOfflineMapDownloaderStateSuspended;
    [self notifyDelegateOfStateChange];
}


- (void)removeOfflineMapDatabase:(MBXOfflineMapDatabase *)offlineMapDatabase
{
    // Get rid of an offline map
    //
    [_mutableOfflineMapDatabases removeObject:offlineMapDatabase];

    //
    // TODO: assuming this is a real offline map, find and delete the associated database on disk
    //
}


@end
