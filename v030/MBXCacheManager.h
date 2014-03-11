//
//  MBXCacheManager.h
//  MBXMapKit
//
//  Created by Will Snook on 3/2/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MBXCacheManagerProtocol.h"

extern NSString const *kMBXNotificationCacheHit;
extern NSString const *kMBXNotificationPersistentDataHit;
extern NSString const *kMBXNotificationHTTPSuccess;
extern NSString const *kMBXNotificationHTTPFail;

@interface MBXCacheManager : NSObject <MBXCacheManagerProtocol>


#pragma mark - Cache configuration

@property (nonatomic) NSTimeInterval cacheInterval;


#pragma mark - Shared cache manager singelton

+ (MBXCacheManager *)sharedCacheManager;


@end
