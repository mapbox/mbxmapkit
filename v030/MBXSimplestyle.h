//
//  MBXSimplestyle.h
//  MBXMapKit
//
//  Created by Will Snook on 3/5/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MBXCacheManagerProtocol.h"
#import "MBXPointAnnotation.h"

@protocol MBXSimplestyleDelegate <NSObject>

- (void)didParseSimplestylePoint:(MBXPointAnnotation *)pointAnnotation;

@optional

- (void)didFailToLoadSimplestyleForMapID:(NSString *)mapID withError:(NSError *)error;

@end


@interface MBXSimplestyle : NSObject

@property (nonatomic) NSString *mapID;

// Note how gets set to a default in init, but after that it can be changed to
// anything that implements MBXCacheManagerProtocol
//
@property (nonatomic) id<MBXCacheManagerProtocol> cacheManager;

@property (nonatomic) NSDictionary *simplestyleJSONDictionary;

@property (weak,nonatomic) id<MBXSimplestyleDelegate> delegate;

@end
