//
//  MBXError.h
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

#import <Foundation/Foundation.h>


#pragma mark - Constants for the MBXMapKit error domain

extern NSString *const MBXMapKitErrorDomain;
extern NSInteger const MBXMapKitErrorCodeHTTPStatus;
extern NSInteger const MBXMapKitErrorCodeDictionaryMissingKeys;
extern NSInteger const MBXMapKitErrorCodeDownloadingCanceled;
extern NSInteger const MBXMapKitErrorCodeOfflineMapHasNoDataForURL;
extern NSInteger const MBXMapKitErrorCodeOfflineMapSqlite;
extern NSInteger const MBXMapKitErrorCodeURLSessionConnectivity;


#pragma mark -

@interface MBXError : NSError

+ (NSError *)errorWithCode:(NSInteger)code reason:(NSString *)reason description:(NSString *)description;

+ (NSError *)errorCannotOpenOfflineMapDatabase:(NSString *)path sqliteError:(const char *)sqliteError;

+ (NSError *)errorQueryFailedForOfflineMapDatabase:(NSString *)path sqliteError:(const char *)sqliteError;

@end
