//
//  MBXMBTilesOverlay.m
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

#import "MBXMBTilesOverlay.h"
#import "MBXMBTilesDatabase.h"

@interface MBXMBTilesOverlay ()

@property (strong, nonatomic) MBXMBTilesDatabase *mbtilesDatabase;

@end

#pragma mark - MBXMBTilesOverlay, a subclass of MKTileOverlay

@implementation MBXMBTilesOverlay

#pragma mark - Initialization

- (instancetype)initWithMBXMBTilesDatabase:(MBXMBTilesDatabase *)mbtileDatabase
{
    if (self = [super init])
    {
        // check mbtiles file
        //
        _mbtilesDatabase = mbtileDatabase;
        
        // 
    }
    return self;
}

#pragma mark - 

@end
