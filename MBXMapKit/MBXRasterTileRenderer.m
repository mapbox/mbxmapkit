#import "MBXRasterTileRenderer.h"

const NSUInteger MBXRasterTileRendererLRUCacheSize = 50;

@interface MBXRasterTileRenderer ()

@property (nonatomic) NSMutableArray *tiles;

@end

@implementation MBXRasterTileRenderer

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

- (MKTileOverlayPath)pathForMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale {
    MKTileOverlay *tileOverlay = (MKTileOverlay *)self.overlay;

    NSInteger x = mapRect.origin.x * zoomScale / tileOverlay.tileSize.width;
    NSInteger y = mapRect.origin.y * zoomScale / tileOverlay.tileSize.width;
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

- (BOOL)canDrawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale {
    MKTileOverlayPath path = [self pathForMapRect:mapRect zoomScale:zoomScale];
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
    CGRect rect = [self rectForMapRect:mapRect];
    NSString *xyz = [self xyzForPath:[self pathForMapRect:mapRect zoomScale:zoomScale]];
    UIImage *image = nil;

    @synchronized(self) {
        NSUInteger index = [[self.tiles valueForKeyPath:@"xyz"] indexOfObject:xyz];
        if (index == NSNotFound) return;
        NSDictionary *tile = self.tiles[index];
        [self.tiles removeObject:tile];
        image = [UIImage imageWithData:tile[@"data"]];
        if (image == nil) return;
        [self.tiles addObject:tile];
    }

    UIGraphicsPushContext(context);
    [image drawInRect:rect];
    UIGraphicsPopContext();
}

- (void)reloadData {
    [self setNeedsDisplay];
}

@end
