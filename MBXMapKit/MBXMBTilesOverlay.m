//
//  MBXMBTilesOverlay.m
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

#import "MBXMBTilesOverlay.h"
#import "MBXMBTilesDatabase.h"


#pragma mark - Private API for cooperating with MBXMBTilesDatabase

@interface MBXMBTilesDatabase ()

- (NSData *)dataForPath:(MKTileOverlayPath)path withError:(NSError **)error;

@end


@interface MBXMBTilesOverlay ()

@property (strong, nonatomic) MBXMBTilesDatabase *mbtilesDatabase;

@end

#pragma mark - MBXMBTilesOverlay, a subclass of MKTileOverlay

@implementation MBXMBTilesOverlay

#pragma mark - Initialization

- (instancetype)initWithMBTilesDatabase:(MBXMBTilesDatabase *)mbtileDatabase
{
    if (self = [super init])
    {
        _mbtilesDatabase = mbtileDatabase;
        
        if ([mbtileDatabase.type isEqualToString:kTypeBaselayer])
        {
            self.canReplaceMapContent = YES;
        }
        
        // 
    }
    return self;
}

#pragma mark - 

@end
