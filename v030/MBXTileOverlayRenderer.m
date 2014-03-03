//
//  MBXTileOverlayRenderer.m
//  MBXMapKit
//
//  Created by Will Snook on 3/2/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXTileOverlayRenderer.h"
#import "MBXCacheManager.h"

@implementation MBXTileOverlayRenderer

- (void)setMapID:(NSString *)mapID
{
    _mapID = mapID;

    // Start listening for broadcast notifications that new TileJSON has finished downloading
    //
    NSString *name = [[MBXCacheManager sharedCacheManager] notificationNameForTileJSON];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(respondToNewTileJSON:) name:name object:[MBXCacheManager sharedCacheManager]];
}

- (void)dealloc
{
    // Stop listening for TileJSON broadcast notifications
    //
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)respondToNewTileJSON:(NSNotification *)notification
{
    // Reload all the tiles when a notification is received that the cache manager has updated the TileJSON for some mapID.
    // If the TileJSON wasn't for this map, that's okay.
    //
    [self reloadData];
}

@end
