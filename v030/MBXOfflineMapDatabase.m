//
//  MBXOfflineMapDatabase.m
//  MBXMapKit
//
//  Created by Will Snook on 3/17/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXOfflineMapDatabase.h"
#import "MBXError.h"


#pragma mark -

@interface MBXOfflineMapDatabase ()

@property (readwrite, nonatomic) NSString *mapID;
@property (readwrite, nonatomic) BOOL metadata;
@property (readwrite, nonatomic) BOOL markers;
@property (readwrite, nonatomic) MBXRasterImageQuality imageQuality;
@property (readwrite, nonatomic) MKCoordinateRegion mapRegion;
@property (readwrite, nonatomic) NSInteger minimumZ;
@property (readwrite, nonatomic) NSInteger maximumZ;

@property (nonatomic) NSString *path;

@property (nonatomic) BOOL initializedProperly;

@end


#pragma mark -

@implementation MBXOfflineMapDatabase

- (id)initWithContentsOfFile:(NSString *)path
{
    self = [super init];

    if(self)
    {
        _path = path;

        //
        // TODO: read the sqlite database at path and use it to set mapID, metadata, markers, ...
        //

        _initializedProperly = YES;
    }

    return self;
}


- (NSData *)dataForKey:(NSString *)key withError:(NSError **)error
{
    // If this assert fails, you may have tried to do something like [[MBXOfflineMapDatabase alloc] init]. Please don't do that!
    // The correct approach is to enumerate the [[MBXOfflineMapDownloader sharedOfflineMapDownloader].offlineMapDatabases array property
    // or to use the database provided by MBXOfflineMapDownloaderDelegate's -offlineMapDownloader:didCompleteOfflineMapDatabase:withError:.
    // Also, the offlineMaps array will only have map databases in it once you have completed downloading at least one offline map region.
    //
    assert(_initializedProperly);

    //
    // TODO: read the database at path and return the appropriate value (or an error)
    //

    if(*error != NULL)
    {
        NSString *reason = [NSString stringWithFormat:@"The offline database has no value for the key %@",key];
        *error = [MBXError errorWithCode:MBXMapKitErrorOfflineMapHasNoDataForKey reason:reason description:@"No offline data for key error"];
    }
    return nil;
}

@end
