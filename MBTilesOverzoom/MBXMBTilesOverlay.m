//
//  MBXMBTilesOverlay.m
//  MBTiles Sample Project
//
//  MBXMapKit Copyright (c) 2013-2015 Mapbox. All rights reserved.
//

#import "MBXMBTilesOverlay.h"
#import <sqlite3.h>


@interface MBXMBTilesOverlay()

@property (nonatomic) NSString *mbtilesPath;
@property (readwrite, nonatomic) NSString *attribution;
@property (readwrite, nonatomic) NSInteger mbtilesMaxZoom;
@property (nonatomic) NSError *noTileForPathError;

@end


#pragma mark -

@implementation MBXMBTilesOverlay

- (id)initWithMBTilesPath:(NSString *)mbtilesPath
{
    self = [super initWithURLTemplate:nil];

    if (self)
    {
        _mbtilesPath = mbtilesPath;

        // We need to know the highest zoom level in the mbtiles file in order to determine when
        // overzooming should be used. Note that overzooming may fail silently if the MBTiles
        // metadata table reports an incorrect maxZoom.
        //
        NSString *maxZoom = [self mbtilesMetadataValueForName:@"maxzoom"];
        if (maxZoom == nil)
        {
            NSLog(@"initWithMBTilesURL: failed to read the MBTiles metadata.");
            return nil;
        }
        self.mbtilesMaxZoom = [maxZoom integerValue];
        
        // Make MBTiles metadata attribution string available as a property
        //
        self.attribution = [self mbtilesMetadataValueForName:@"attribution"];

        // By default, assume this overlay is not the basemap layer
        //
        self.canReplaceMapContent = NO;
        
        // Create a reusable error message for mbtiles:dataForSingleColumnQuery: since it will potentially
        // need to use this a lot for tiles that aren't included in the mbtiles file.
        //
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"MBTiles file has no tile for given path"};
        self.noTileForPathError = [NSError errorWithDomain:@"MBXMBTilesOverlayErrorDomain" code:-1 userInfo:userInfo];
        
    }

    return self;
}


- (NSString *)mbtilesMetadataValueForName:(NSString *)name
{
    NSString *query = [NSString stringWithFormat:@"SELECT value FROM metadata WHERE name='%@';",name];
    NSData *data = [self mbtiles:_mbtilesPath dataForSingleColumnQuery:query];
    NSString *s;
    if (data == nil) {
        s = nil;
    } else {
        s = [[NSString alloc] initWithBytes:data.bytes length:data.length encoding:NSUTF8StringEncoding];
    }
    return s;
}


- (NSData *)mbtilesImageDataForPath:(MKTileOverlayPath)path
{
    NSString *query = [NSString stringWithFormat:@"select tile_data from tiles where zoom_level = %ld and tile_column = %ld and tile_row = %ld",(long)path.z,(long)path.x,(long)path.y];;
    NSData *data = [self mbtiles:_mbtilesPath dataForSingleColumnQuery:query];
    if(data && data.length==0)
    {
        // NSData objects with 0 bytes of data cause problems, so return nil instead
        return nil;
    }
    else
    {
        return UIImagePNGRepresentation([UIImage imageWithData:data]);
    }
}


- (NSData *)mbtiles:(NSString *)mbtilesPath dataForSingleColumnQuery:(NSString *)query
{
    // This sqlite database read is designed to be called from multiple simultaneous MKMapKit
    // tile loading threads. Because the database connection is uniqe rather than shared, and because
    // all the access is read only, libsqlite's built in multi-threading features are sufficient
    // and no additional synchronization is required. For background, refer to the sqlite documenation:
    // - http://sqlite.org/faq.html#q5
    // - http://www.sqlite.org/threadsafe.html
    // - http://www.sqlite.org/c3ref/threadsafe.html
    //
    assert(sqlite3_threadsafe()==2);

    // Open the database read-only and multi-threaded. The terse c-style variable
    // names here and below are used to stay consistent with the sqlite documentaion. See
    // http://sqlite.org/c3ref/open.html
    //
    sqlite3 *db;
    int rc;
    const char *filename = [mbtilesPath cStringUsingEncoding:NSUTF8StringEncoding];
    rc = sqlite3_open_v2(filename, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, NULL);
    if (rc)
    {
        NSLog(@"Can't open database: %s", sqlite3_errmsg(db));
        sqlite3_close(db);
        return nil;
    }

    // Prepare the query
    const char *zSql = [query cStringUsingEncoding:NSUTF8StringEncoding];
    int nByte = (int)[query lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    sqlite3_stmt *ppStmt;
    const char *pzTail;
    rc = sqlite3_prepare_v2(db, zSql, nByte, &ppStmt, &pzTail);
    if (rc)
    {
        NSLog(@"Problem preparing sql statement: %s", sqlite3_errmsg(db));
        sqlite3_finalize(ppStmt);
        sqlite3_close(db);
        return nil;
    }

    // Evaluate the query,
    NSData *data = nil;
    rc = sqlite3_step(ppStmt);
    if (rc == SQLITE_ROW)
    {
        data = [NSData dataWithBytes:sqlite3_column_blob(ppStmt, 0) length:sqlite3_column_bytes(ppStmt, 0)];
    }
    else if (rc == SQLITE_DONE)
    {
        // The query returned no results. This is a normal, frequent, and harmless outcome for
        // maps which do not cover the whole world.
    }
    else if (rc == SQLITE_BUSY)
    {
        // This is bad, but theoretically it should never happen
        NSLog(@"sqlite3_step() returned SQLITE_BUSY. You probably have a concurrency problem.");
    }
    else
    {
        NSLog(@"sqlite3_step() isn't happy: %s", sqlite3_errmsg(db));
    }

    // Clean up
    sqlite3_finalize(ppStmt);
    sqlite3_close(db);
    return data;
}



#pragma mark -

- (MKTileOverlayPath)enclosingTileForOverzoomedPath:(MKTileOverlayPath)path atZoom:(NSInteger)zoom
{
    // For the overzoomed tile specified by path, figure out which tile from
    // level _mbtilesMaximumZ encloses that same location
    assert(path.z > self.mbtilesMaxZoom && path.z < 30);
    MKTileOverlayPath enclosingTilePath;

    // Use integer division to get the quotient and discard the remainder...
    int divisor = 1 << (path.z - zoom);
    enclosingTilePath.x = path.x / divisor;
    enclosingTilePath.y = path.y / divisor;
    enclosingTilePath.z = zoom;
    return enclosingTilePath;
}


- (NSData *)extractTileAtPath:(MKTileOverlayPath)destPath fromTile:(NSData *)tile atPath:(MKTileOverlayPath)sourcePath
{
    // Load the source tile image which we know came from the _mbtilesMaxZoom zoom level
    //
    assert(sourcePath.z < destPath.z && destPath.z < 30);
    NSData *overzoomedTile;
    UIImage *source = [UIImage imageWithData:tile];
    if(source==nil)
    {
        return nil;
    }
    
    // Calculate the path to use for cropping within the source tile. Note that the
    // coordinate system for UIImage is upsidedown from the XYZ tile coordinate system.
    //
    int normalizedSideLength = 1 << (destPath.z - sourcePath.z);
    CGFloat x = destPath.x % (normalizedSideLength);
    CGFloat y = destPath.y % (normalizedSideLength);
    
    // Calculate the rect to use for scaling
    //
    CGRect scalingRect;
    scalingRect.origin.x = 0.0 - x * 256.0;
    scalingRect.origin.y = 0.0 - (normalizedSideLength - 1 - y) * 256.0;
    scalingRect.size.width = 256.0 * normalizedSideLength;
    scalingRect.size.height = 256.0 * normalizedSideLength;
    
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
    // MKMapKit's Default coordinate system is upside down relative to an
    // MBTiles file from TileMill, so flip it
    return YES;
}


- (void)loadTileAtPath:(MKTileOverlayPath)path result:(void (^)(NSData *tileData, NSError *error))result
{
    //printf("  %ld,%ld,%ld\n",(long)path.x,(long)path.y,(long)path.z);

    NSData *data = nil;
    if(self.mbtilesMaxZoom >= path.z)
    {
        // Within MBTiles file's zoom limit, so just get the tile image
        data = [self mbtilesImageDataForPath:path];
    }
    else
    {
        // Beyond MBTiles file's zoom limit, so we need to overzoom
        MKTileOverlayPath enclosingPath = [self enclosingTileForOverzoomedPath:path atZoom:self.mbtilesMaxZoom];
        NSData *enclosingTile = [self mbtilesImageDataForPath:enclosingPath];
        if(enclosingTile)
        {
            data = [self extractTileAtPath:path fromTile:enclosingTile atPath:enclosingPath];
        }
    }
    if(data==nil)
    {
        result(data,self.noTileForPathError);
    }
    else
    {
        result(data, nil);
    }
}


- (CLLocationCoordinate2D)coordinate
{
    return CLLocationCoordinate2DMake(0, 0);
}


- (MKMapRect)boundingMapRect
{
    // Things tend work more predictably if you use MKMapRectWorld here, although it does
    // perhaps result in more calls to loadTileAtPath:result: than might be strictly
    // necessary. The upside is that when loadTileAtPath:result: is called, you have
    // control over what happens for that tile.
    return MKMapRectWorld;
}



@end
