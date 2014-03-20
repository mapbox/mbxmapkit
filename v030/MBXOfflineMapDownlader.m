//
//  MBXOfflineMapDownloader.m
//  MBXMapKit
//
//  Created by Will Snook on 3/19/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXOfflineMapDownloader.h"


#pragma mark -

@interface MBXOfflineMapDownloader ()

@property (readwrite, nonatomic) NSString *mapID;
@property (readwrite, nonatomic) MKCoordinateRegion mapRegion;
@property (readwrite, nonatomic) NSInteger minimumZ;
@property (readwrite, nonatomic) NSInteger maximumZ;
@property (readwrite, nonatomic) MBXOfflineMapDownloaderState state;

@property (nonatomic) id<MBXOfflineMapDownloaderDelegate> delegate;

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


- (void)beginDownloadingMapID:(NSString *)mapID mapRegion:(MKCoordinateRegion)mapRegion minimumZ:(NSInteger)minimumZ maximumZ:(NSInteger)maximumZ
{
    // Start a download job to retrieve all the resources needed for using the specified map offline
    //
    _mapID = mapID;
    _mapRegion = mapRegion;
    _minimumZ = minimumZ;
    _maximumZ = maximumZ;
    _state = MBXOfflineMapDownloaderStateRunning;
}


- (void)cancel
{
    // Stop a download job and discard the associated files
    //
    _state = MBXOfflineMapDownloaderStateCanceling;
}


- (void)resume
{
    if(_state == MBXOfflineMapDownloaderStateSuspended)
    {
        // Resume a previously suspended download job
        //
        _state = MBXOfflineMapDownloaderStateRunning;
    }
    else
    {
        // Complain about how it isn't possible to resume unless there is a suspended download job
        //
        if([_delegate respondsToSelector:@selector(offlineMapDownloader:didCompleteOfflineMapDatabase:withError:)])
        {
            NSError *error = [MBXError errorWithCode:MBXMapKitErrorNothingToDo
                                              reason:@"The offline map downloader can only resume when it has a suspended map download to finish, but it doesn't have one of those right now."
                                         description:@"Nothing to do error"];
            [_delegate offlineMapDownloader:self didCompleteOfflineMapDatabase:nil withError:error];
        }
    }
}


- (void)suspend
{
    // Stop a download job and preserve the necessary state to resume later
    //
    _state = MBXOfflineMapDownloaderStateSuspended;
}



@end
