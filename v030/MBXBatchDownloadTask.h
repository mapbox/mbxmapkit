//
//  MBXBatchDownloadTask.h
//  MBXMapKit
//
//  Created by Will Snook on 3/17/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

#pragma mark - Error constants

extern NSString *const MBXMapKitErrorDomain;
extern NSInteger const MBXMapKitErrorDownloadTaskCanceled;


#pragma mark - Delegate protocol for progress updates

@class MBXBatchDownloadTask;
@class MBXOfflineMapDatabase;

@protocol MBXBatchDownloadTaskDelegate

- (void)batchDownloadTask:(MBXBatchDownloadTask *)batchDownloadTask totalFilesExpectedToWrite:(NSUInteger)totalFilesExpectedToWrite;

- (void)batchDownloadTask:(MBXBatchDownloadTask *)batchDownloadTask totalFilesWritten:(NSUInteger)totalFilesWritten totalFilesExpectedToWrite:(NSUInteger)totalFilesExpectedToWrite;

- (void)batchDownloadTask:(MBXBatchDownloadTask *)batchDownloadTask didCompleteWithError:(NSError *)error;

@end


#pragma mark - 

@interface MBXBatchDownloadTask : NSObject


#pragma mark - Class methods to manage download tasks

+ (MBXBatchDownloadTask *)downloadTaskForMapID:(NSString *)mapID offlineMapRegion:(MKCoordinateRegion)offlineMapRegion minimumZ:(NSInteger)minimumZ maximumZ:(NSInteger)maximumZ;

+ (NSArray *)tasksInProgress;

+ (NSArray *)completedTasks;

+ (MBXBatchDownloadTask *)taskForMapID:(NSString *)mapID;


#pragma mark - Instance properties and methods

@property (readonly, nonatomic) NSString *mapID;
@property (readonly, nonatomic) MKCoordinateRegion mapRegion;
@property (readonly, nonatomic) NSInteger minimumZ;
@property (readonly, nonatomic) NSInteger maximumZ;

@property (readonly, nonatomic) MBXOfflineMapDatabase *mapDatabase;
@property (readonly, nonatomic) BOOL taskComplete;

- (void)cancel;
- (void)resume;
- (void)suspend;


@end
