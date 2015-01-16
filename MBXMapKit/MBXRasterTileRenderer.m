//
//  MBXRasterTileRenderer.m
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

#import "MBXRasterTileRenderer.h"

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

- (NSUInteger)cacheMaxSize {
    if (((MKTileOverlay *)self.overlay).tileSize.width == 512) {
        return 12;
    } else {
        return 48;
    }
}

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

+ (NSString *)xyzForPath:(MKTileOverlayPath)path {
    NSString *xyz = [NSString stringWithFormat:@"%li-%li-%li",
        (long)path.x,
        (long)path.y,
        (long)path.z];

    return xyz;
}

+ (MKTileOverlayPath)pathForXYZ:(NSString *)xyz scaleFactor:(CGFloat)scaleFactor {
    MKTileOverlayPath path = {
        .x = [[xyz componentsSeparatedByString:@"-"][0] integerValue],
        .y = [[xyz componentsSeparatedByString:@"-"][1] integerValue],
        .z = [[xyz componentsSeparatedByString:@"-"][2] integerValue],
        .contentScaleFactor = scaleFactor
    };

    return path;
}

+ (void)addImageData:(NSData *)data toRenderer:(MBXRasterTileRenderer *)renderer forXYZ:(NSString *)xyz usingParents:(BOOL)usingParents {
    while (renderer.tiles.count >= [renderer cacheMaxSize]) {
        [renderer.tiles removeObjectAtIndex:0];
    }

    if (usingParents) {
        MKTileOverlayPath parentPath = [[renderer class] pathForXYZ:xyz scaleFactor:renderer.contentScaleFactor];
        parentPath.x /= 2;
        parentPath.y /= 2;
        parentPath.z--;

        NSString *parentXYZ = [[renderer class] xyzForPath:parentPath];

        if (![[renderer.tiles valueForKeyPath:@"xyz"] containsObject:parentXYZ]) {
            [renderer.tiles addObject:@{
                @"xyz": parentXYZ,
                @"data": data
            }];
        }
    } else {
        if (![[renderer.tiles valueForKeyPath:@"xyz"] containsObject:xyz]) {
            [renderer.tiles addObject:@{
                @"xyz": xyz,
                @"data": data
            }];
        }
    }
}

+ (NSData *)imageDataFromRenderer:(MBXRasterTileRenderer *)renderer forXYZ:(NSString *)xyz usingParents:(BOOL)usingParents {
    NSString *searchXYZ;
    if (usingParents) {
        MKTileOverlayPath path = [[renderer class] pathForXYZ:xyz scaleFactor:renderer.contentScaleFactor];
        path.x /= 2;
        path.y /= 2;
        path.z--;
        searchXYZ = [[renderer class] xyzForPath:path];
    } else {
        searchXYZ = xyz;
    }

    NSDictionary *tile = nil;

    for (tile in renderer.tiles) {
        if ([tile[@"xyz"] isEqualToString:searchXYZ]) {
            break;
        }
    }

    if (!tile) return nil;

    [renderer.tiles removeObject:tile];
    [renderer.tiles addObject:tile];

    return tile[@"data"];
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
    NSString *xyz = [[self class] xyzForPath:childPath];
    BOOL tileReady = NO;

    @synchronized(self) {
        tileReady = ([[self class] imageDataFromRenderer:self forXYZ:xyz usingParents:usingBigTiles] != nil);
    }

    if (tileReady) {
        return YES;
    } else {
        __weak typeof(self) weakSelf = self;
        [(MKTileOverlay *)weakSelf.overlay loadTileAtPath:path result:^(NSData *tileData, NSError *error) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                if (tileData) {
                    CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)tileData);
                    CGImageRef imageRef = CGImageCreateWithPNGDataProvider(provider, nil, NO, kCGRenderingIntentDefault);
                    if (!imageRef) imageRef = CGImageCreateWithJPEGDataProvider(provider, nil, NO, kCGRenderingIntentDefault);
                    CGDataProviderRelease(provider);
                    if (imageRef) {
                        @synchronized(weakSelf) {
                            [[weakSelf class] addImageData:tileData
                                                toRenderer:weakSelf
                                                    forXYZ:xyz
                                              usingParents:usingBigTiles];
                        }
                    }
                    CGImageRelease(imageRef);
                }
                [weakSelf setNeedsDisplayInMapRect:mapRect zoomScale:zoomScale];
            });
        }];
        return NO;
    }
}

- (void)drawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale inContext:(CGContextRef)context {
    MKTileOverlayPath path = [self pathForMapRect:mapRect zoomScale:zoomScale];
    NSString *xyz = [[self class] xyzForPath:path];
    NSData *tileData = nil;

    @synchronized(self) {
        tileData = [[self class] imageDataFromRenderer:self
                                                forXYZ:xyz
                                          usingParents:(((MKTileOverlay *)self.overlay).tileSize.width == 512)];
        if (!tileData) return;
    }

    CGImageRef imageRef = nil;

    CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)tileData);
    if (provider) {
        imageRef = CGImageCreateWithPNGDataProvider(provider, nil, NO, kCGRenderingIntentDefault);
        if (!imageRef) imageRef = CGImageCreateWithJPEGDataProvider(provider, nil, NO, kCGRenderingIntentDefault);
        CGDataProviderRelease(provider);
    }

    if (!imageRef) {
        return [self setNeedsDisplayInMapRect:mapRect zoomScale:zoomScale];
    }

    CGImageRef croppedImageRef = nil;

    if (CGImageGetWidth(imageRef) == 512) {
        CGRect cropRect = CGRectMake(0, 0, 256, 256);
        cropRect.origin.x += (path.x % 2 ? 256 : 0);
        cropRect.origin.y += (path.y % 2 ? 256 : 0);
        croppedImageRef = CGImageCreateWithImageInRect(imageRef, cropRect);
    }

    CGRect tileRect = CGRectMake(0, 0, 256, 256);
    UIGraphicsBeginImageContext(tileRect.size);
    CGContextDrawImage(UIGraphicsGetCurrentContext(), tileRect, (croppedImageRef ? croppedImageRef : imageRef));
    CGImageRelease(croppedImageRef);
    CGImageRelease(imageRef);
    CGImageRef flippedImageRef = UIGraphicsGetImageFromCurrentImageContext().CGImage;
    UIGraphicsEndImageContext();

    CGContextDrawImage(context, [self rectForMapRect:mapRect], flippedImageRef);
}

#pragma mark - MKTileOverlayRenderer Compatibility

- (void)reloadData {
    [self setNeedsDisplay];
}

@end
