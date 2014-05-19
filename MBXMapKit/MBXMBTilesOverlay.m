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
        if (mbtileDatabase)
        {
            _mbtilesDatabase = mbtileDatabase;
            
            if ([mbtileDatabase.type isEqualToString:kTypeBaselayer])
            {
                // A baselayer is assumed to have opaque tiles
                //
                self.canReplaceMapContent = YES;
            }
            
            _zoomLimit = 20;
            
        }
    }
    return self;
}

- (MKTileOverlayPath)enclosingTileForOverzoomedPath:(MKTileOverlayPath)path atZoom:(NSInteger)zoom
{
    // For the overzoomed tile specified by path, figure out which tile from level _tileSourceMaxZoom encloses that same location
    assert(path.z > self.mbtilesDatabase.maximumZ && path.z < 30);
    MKTileOverlayPath enclosingTilePath;
    // Intentionally using integer division here to get the quotient and discard the remainder...
    int divisor = 1 << (path.z - zoom);
    enclosingTilePath.x = path.x / divisor;
    enclosingTilePath.y = path.y / divisor;
    enclosingTilePath.z = zoom;
    return enclosingTilePath;
}

- (NSData *)extractTileAtPath:(MKTileOverlayPath)destPath fromTile:(NSData *)tile atPath:(MKTileOverlayPath)sourcePath
{
    // Load the source tile image which we know came from _tileSourceMaxZoom zoom level
    //
    assert(sourcePath.z < destPath.z && destPath.z < 30);
    NSData *overzoomedTile;
    UIImage *source = [UIImage imageWithData:tile];
    assert(source != nil);
    
    // Calculate the path to use for cropping within the source tile. Note that the coordinate system for UIImage is upsidedown
    // from the XYZ tile coordinate system.
    //
    int normalizedSideLength = 1 << (destPath.z - sourcePath.z);
    CGFloat x = destPath.x % (normalizedSideLength);
    CGFloat y = destPath.y % (normalizedSideLength);
    
    // Calculate the rect to use for scaling
    //
    CGRect scalingRect;
    scalingRect.origin.x = 0.0 - x*256.0;
    scalingRect.origin.y = 0.0 - (normalizedSideLength-1-y)*256.0;
    scalingRect.size.width = 256.0*normalizedSideLength;
    scalingRect.size.height = 256.0*normalizedSideLength;
    
    // Set up a destination image, same size as the source
    //
    UIGraphicsBeginImageContextWithOptions(source.size, NO, source.scale);
    // Crop & scale
    [source drawInRect:scalingRect];
    UIImage *destination = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    overzoomedTile = UIImagePNGRepresentation(destination);
    return overzoomedTile;
}

#pragma mark - MKTileOverlay implementation

- (BOOL)isGeometryFlipped
{
    // Default coordinate system is upside down relative to an
    // MBTiles file from TileMill, so flip it
    return YES;
}

- (MKMapRect)boundingMapRect
{
    
    return MKMapRectIsNull(self.mbtilesDatabase.mapRect) ? MKMapRectWorld : self.mbtilesDatabase.mapRect;
}

- (void)loadTileAtPath:(MKTileOverlayPath)path result:(void (^)(NSData *tileData, NSError *error))result
{
    NSData *data;
    
    if(self.zoomLimit >= path.z) {
        // Within regular zoom limits: Retrieve and return the specified tile
        //
        data = [self.mbtilesDatabase dataForPath:path withError:nil];
    } else {
        if (self.shouldOverzoom) {
            // Overzoomed: Retrieve the enclosing tile at the higest available zoom level, scale, crop, and return
            //
            MKTileOverlayPath enclosingTilePath = [self enclosingTileForOverzoomedPath:path atZoom:self.zoomLimit];
            NSData *enclosingTile = [self.mbtilesDatabase dataForPath:enclosingTilePath withError:nil];
            if(enclosingTile) {
                data = [self extractTileAtPath:path fromTile:enclosingTile atPath:enclosingTilePath];
            }
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        result(data, nil);
    });
    
}

@end
