//
//  MBXRasterTileRenderer.m
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

#import "MBXRasterTileRenderer.h"

const NSUInteger MBXRasterTileRendererLRUCacheSize = 50;

#pragma mark - Private API

@interface MBXRasterTileRenderer ()

@property (nonatomic) NSMutableArray *tiles;

@end

@implementation MBXRasterTileRenderer

#pragma mark - Setup

- (id)initWithOverlay:(id<MKOverlay>)overlay {
    NSAssert([overlay isKindOfClass:[MKTileOverlay class]], @"overlay must be an MKTileOverlay");

    self = [super initWithOverlay:overlay];

    if (self) {
        _tiles = [NSMutableArray new];
    }

    return self;
}

- (id)initWithTileOverlay:(MKTileOverlay *)overlay {
    return [self initWithOverlay:overlay];
}

#pragma mark - Utility

- (MKTileOverlayPath)pathForMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale {
    MKTileOverlay *tileOverlay = (MKTileOverlay *)self.overlay;
    CGFloat factor = tileOverlay.tileSize.width / 256;

    NSInteger x = round(mapRect.origin.x * zoomScale / (tileOverlay.tileSize.width / factor));
    NSInteger y = round(mapRect.origin.y * zoomScale / (tileOverlay.tileSize.width / factor));
    NSInteger z = log2(zoomScale) + 20;

    MKTileOverlayPath path = {
        .x = x,
        .y = y,
        .z = z,
        .contentScaleFactor = self.contentScaleFactor
    };

    return path;
}

- (NSString *)xyzForPath:(MKTileOverlayPath)path {
    NSString *xyz = [NSString stringWithFormat:@"%li-%li-%li",
        (long)path.x,
        (long)path.y,
        (long)path.z];

    return xyz;
}

#pragma mark - MKOverlayRenderer Overrides

- (BOOL)canDrawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale {
    MKTileOverlay *tileOverlay = (MKTileOverlay *)self.overlay;
    MKTileOverlayPath path = [self pathForMapRect:mapRect zoomScale:zoomScale];
    BOOL bigTiles = (tileOverlay.tileSize.width / 256 > 1);
    if (bigTiles) {
        path.x /= 2;
        path.y /= 2;
        path.z -= 1;
    }
    NSString *xyz = [self xyzForPath:path];
    BOOL tileReady = NO;

    @synchronized(self) {
        tileReady = [[self.tiles valueForKeyPath:@"xyz"] containsObject:xyz];
    }

    if (tileReady) {
        return YES;
    } else {
        __weak typeof(self) weakSelf = self;
        [(MKTileOverlay *)weakSelf.overlay loadTileAtPath:path result:^(NSData *tileData, NSError *error) {
            if (tileData) {
                @synchronized(weakSelf) {
                    while (weakSelf.tiles.count >= MBXRasterTileRendererLRUCacheSize) {
                        [weakSelf.tiles removeObjectAtIndex:0];
                    }
                    [weakSelf.tiles addObject:@{
                        @"xyz": xyz,
                        @"data": tileData
                    }];
                }
                [weakSelf setNeedsDisplayInMapRect:mapRect zoomScale:zoomScale];
            }
        }];
        return NO;
    }
}

- (void)drawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale inContext:(CGContextRef)context {
    MKTileOverlay *tileOverlay = (MKTileOverlay *)self.overlay;
    CGRect rect = [self rectForMapRect:mapRect];
    MKTileOverlayPath path = [self pathForMapRect:mapRect zoomScale:zoomScale];
    BOOL bigTiles = (tileOverlay.tileSize.width / 256 > 1);
    MKTileOverlayPath childPath = path;
    if (bigTiles) {
        path.x /= 2;
        path.y /= 2;
        path.z -= 1;
    }
    NSString *xyz = [self xyzForPath:path];
    UIImage *image = nil;
    BOOL success = NO;

    @synchronized(self) {
        NSUInteger index = [[self.tiles valueForKeyPath:@"xyz"] indexOfObject:xyz];
        if (index != NSNotFound) {
            NSDictionary *tile = self.tiles[index];
            [self.tiles removeObject:tile];
            image = [UIImage imageWithData:tile[@"data"]];
            if (image != nil) {
                [self.tiles addObject:tile];
                success = YES;
            }
        }
    }

    if (!success) {
        return [self setNeedsDisplayInMapRect:mapRect zoomScale:zoomScale];
    }

    if (bigTiles) {
        CGFloat childSize = image.size.width / 2;
        CGRect cropRect = CGRectMake(0, 0, childSize, childSize);
        if (childPath.x > path.x * 2) cropRect.origin.x += childSize;
        if (childPath.y > path.y * 2) cropRect.origin.y += childSize;
        CGImageRef croppedImage = CGImageCreateWithImageInRect(image.CGImage, cropRect);
        image = [UIImage imageWithCGImage:croppedImage];
    }

    UIGraphicsPushContext(context);
    [image drawInRect:rect];
    UIGraphicsPopContext();
}

#pragma mark - MKTileOverlayRenderer Compatibility

- (void)reloadData {
    [self setNeedsDisplay];
}

@end
