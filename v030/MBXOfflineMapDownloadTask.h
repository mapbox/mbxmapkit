//
//  MBXOfflineMapDownloadTask.h
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

@class MBXOfflineMapDownloadTask;
@class MBXOfflineMapDatabase;
@protocol MBXOfflineMapDownloadTaskDelegate

- (void)mapDownloadTask:(MBXOfflineMapDownloadTask *)mapDownloadTask totalFilesExpectedToWrite:(NSUInteger)totalFilesExpectedToWrite;

- (void)mapDownloadTask:(MBXOfflineMapDownloadTask *)mapDownloadTask totalFilesWritten:(NSUInteger)totalFilesWritten totalFilesExpectedToWrite:(NSUInteger)totalFilesExpectedToWrite;

- (void)mapDownloadTask:(MBXOfflineMapDownloadTask *)mapDownloadTask didCompleteWithError:(NSError *)error;

@end


#pragma mark - 

@interface MBXOfflineMapDownloadTask : NSObject

#pragma mark - Class methods to manage download tasks

+ (MBXOfflineMapDownloadTask *)downloadTaskForMapID:(NSString *)mapID offlineMapRegion:(MKCoordinateRegion)offlineMapRegion minimumZ:(NSInteger)minimumZ maximumZ:(NSInteger)maximumZ;

+ (NSArray *)tasksInProgress;

+ (NSArray *)completedTasks;

+ (MBXOfflineMapDatabase *)databaseForMapID:(NSString *)mapID;


#pragma mark - Instance properties and methods

@property (readonly, nonatomic) NSString *mapID;
@property (readonly, nonatomic) MKCoordinateRegion mapRegion;
@property (readonly, nonatomic) NSInteger minimumZ;
@property (readonly, nonatomic) NSInteger maximumZ;

@property (readonly, nonatomic) MBXOfflineMapDatabase *mapDatabase;

- (void)cancel;
- (void)resume;
- (void)suspend;
@property (readonly, nonatomic) BOOL taskComplete;


@end
