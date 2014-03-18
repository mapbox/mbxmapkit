//
//  MBXOfflineMapDatabase.m
//  MBXMapKit
//
//  Created by Will Snook on 3/17/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXOfflineMapDatabase.h"

#pragma mark -

@interface MBXOfflineMapDatabase ()

@property (readwrite, nonatomic) NSString *mapID;
@property (readwrite, nonatomic) MKCoordinateRegion mapRegion;
@property (readwrite, nonatomic) NSInteger minimumZ;
@property (readwrite, nonatomic) NSInteger maximumZ;

@end


#pragma mark -

@implementation MBXOfflineMapDatabase

- (NSData *)dataForKey:(NSString *)key withError:(NSError *)error
{
    return nil;
}

@end
