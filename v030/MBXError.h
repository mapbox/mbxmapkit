//
//  MBXError.h
//  MBXMapKit
//
//  Created by Will Snook on 3/19/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import <Foundation/Foundation.h>


#pragma mark - Constants for the MBXMapKit error domain

extern NSString *const MBXMapKitErrorDomain;
extern NSInteger const MBXMapKitErrorCodeHTTPStatus;
extern NSInteger const MBXMapKitErrorCodeDictionaryMissingKeys;
extern NSInteger const MBXMapKitErrorCodeDownloadingCanceled;
extern NSInteger const MBXMapKitErrorCodeOfflineMapHasNoDataForKey;
extern NSInteger const MBXMapKitErrorCodeOfflineMapSqlite;
extern NSInteger const MBXMapKitErrorCodeURLSessionConnectivity;


#pragma mark -

@interface MBXError : NSError

+ (NSError *)errorWithCode:(NSInteger)code reason:(NSString *)reason description:(NSString *)description;

+ (NSError *)errorCannotOpenOfflineMapDatabase:(NSString *)path sqliteError:(const char *)sqliteError;

+ (NSError *)errorQueryFailedForOfflineMapDatabase:(NSString *)path sqliteError:(const char *)sqliteError;

@end
