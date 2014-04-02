//
//  MBXOfflineMapDownloader.m
//  MBXMapKit
//
//  Created by Will Snook on 3/19/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXOfflineMapDownloader.h"
#import "MBXOfflineMapDatabase.h"


#pragma mark -

@interface MBXOfflineMapDownloader ()

@property (readwrite, nonatomic) NSString *mapID;
@property (readwrite, nonatomic) MKCoordinateRegion mapRegion;
@property (readwrite, nonatomic) NSInteger minimumZ;
@property (readwrite, nonatomic) NSInteger maximumZ;
@property (readwrite, nonatomic) MBXOfflineMapDownloaderState state;

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

- (id)init
{
    self = [super init];

    if(self)
    {
        _state = MBXOfflineMapDownloaderStateAvailable;
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
    assert(_state == MBXOfflineMapDownloaderStateAvailable);

    // Start a download job to retrieve all the resources needed for using the specified map offline
    //
    _mapID = mapID;
    _mapRegion = mapRegion;
    _minimumZ = minimumZ;
    _maximumZ = maximumZ;
    _state = MBXOfflineMapDownloaderStateRunning;
    [self notifyDelegateOfStateChange];

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


@end
