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

- (void)addImageData:(NSData *)data toCache:(NSMutableArray *)cache forXYZ:(NSString *)xyz {
    while (cache.count >= MBXRasterTileRendererLRUCacheSize) {
        [cache removeObjectAtIndex:0];
    }
    [cache addObject:@{
        @"xyz": xyz,
        @"data": data
    }];
}

#pragma mark - MKOverlayRenderer Overrides

- (BOOL)canDrawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale {
    MKTileOverlay *tileOverlay = (MKTileOverlay *)self.overlay;
    MKTileOverlayPath path = [self pathForMapRect:mapRect zoomScale:zoomScale];
    BOOL usingBigTiles = (tileOverlay.tileSize.width == 512);
    MKTileOverlayPath childPath = path;
    if (usingBigTiles) {
        path.x /= 2;
        path.y /= 2;
        path.z -= 1;
    }
    NSString *xyz = [self xyzForPath:childPath];
    BOOL tileReady = NO;

    @synchronized(self) {
        tileReady = [[self.tiles valueForKeyPath:@"xyz"] containsObject:xyz];
    }

    if (tileReady) {
        return YES;
    } else {
        __weak typeof(self) weakSelf = self;
        [(MKTileOverlay *)weakSelf.overlay loadTileAtPath:path result:^(NSData *tileData, NSError *error) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                if (tileData) {
                    UIImage *image = nil;
                    if (usingBigTiles && (image = [UIImage imageWithData:tileData])) {
                        for (NSUInteger x = 0; x < 2; x++) {
                            for (NSUInteger y = 0; y < 2; y++) {
                                CGRect cropRect = CGRectMake(0, 0, 256, 256);
                                cropRect.origin.x += (x * 256);
                                cropRect.origin.y += (y * 256);
                                MKTileOverlayPath quarterPath = {
                                    .x = path.x * 2 + x,
                                    .y = path.y * 2 + y,
                                    .z = path.z + 1,
                                    .contentScaleFactor = weakSelf.contentScaleFactor
                                };
                                NSString *quarterXYZ = [weakSelf xyzForPath:quarterPath];
                                @synchronized(weakSelf) {
                                    if (![[weakSelf.tiles valueForKeyPath:@"xyz"] containsObject:quarterXYZ]) {
                                        CGImageRef quarterImage = CGImageCreateWithImageInRect(image.CGImage, cropRect);
                                        NSData *quarterData = UIImagePNGRepresentation([UIImage imageWithCGImage:quarterImage]);
                                        [weakSelf addImageData:quarterData toCache:weakSelf.tiles forXYZ:quarterXYZ];
                                    }
                                }
                            }
                        }
                    } else if (!usingBigTiles) {
                        @synchronized(weakSelf) {
                            [weakSelf addImageData:tileData toCache:weakSelf.tiles forXYZ:xyz];
                        }
                    }
                }
                [weakSelf setNeedsDisplayInMapRect:mapRect zoomScale:zoomScale];
            });
        }];
        return NO;
    }
}

- (void)drawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale inContext:(CGContextRef)context {
    MKTileOverlayPath path = [self pathForMapRect:mapRect zoomScale:zoomScale];
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

    UIGraphicsPushContext(context);
    [image drawInRect:[self rectForMapRect:mapRect]];
    UIGraphicsPopContext();
}

#pragma mark - MKTileOverlayRenderer Compatibility

- (void)reloadData {
    [self setNeedsDisplay];
}

@end
