//
//  MBXError.m
//  MBXMapKit
//
//  Created by Will Snook on 3/19/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXError.h"


#pragma mark - Constants for the MBXMapKit error domain

NSString *const MBXMapKitErrorDomain = @"MBXMapKitErrorDomain";
NSInteger const MBXMapKitErrorCodeHTTPStatus = -1;
NSInteger const MBXMapKitErrorCodeDictionaryMissingKeys = -2;
NSInteger const MBXMapKitErrorDownloadingCanceled = -3;
NSInteger const MBXMapKitErrorOfflineMapHasNoDataForKey = -4;
NSInteger const MBXMapKitErrorOfflineMapSqlite = -5;


#pragma mark -

@implementation MBXError

+ (NSError *)errorWithCode:(NSInteger)code reason:(NSString *)reason description:(NSString *)description
{
    // Return an error in the MBXMapKit error domain with the specified reason and description
    //
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey        : NSLocalizedString(description, nil),
                                NSLocalizedFailureReasonErrorKey : NSLocalizedString(reason, nil) };

    return [NSError errorWithDomain:MBXMapKitErrorDomain code:code userInfo:userInfo];
}


+ (NSError *)errorCannotOpenOfflineMapDatabase:(NSString *)path sqliteError:(const char *)sqliteError
{
    return [MBXError errorWithCode:MBXMapKitErrorOfflineMapSqlite reason:[NSString stringWithFormat:@"Unable to open database %@: %@", path, [NSString stringWithUTF8String:sqliteError]] description:@"Failed to open the sqlite offline map database file"];
}

+ (NSError *)errorQueryFailedForOfflineMapDatabase:(NSString *)path sqliteError:(const char *)sqliteError
{
    return [MBXError errorWithCode:MBXMapKitErrorOfflineMapSqlite reason:[NSString stringWithFormat:@"There was an sqlite error while executing a query on database %@: %@", path, [NSString stringWithUTF8String:sqliteError]] description:@"Failed to execute query"];
}

@end
