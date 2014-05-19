//
//  MBXMBTilesDatabase.m
//  MBXMapKit
//
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXMBTilesDatabase.h"
#import <sqlite3.h>


// TODO: implement MBTiles-spec either as class or introduce a class method that
// can read specs from a json file for example. MBXMBTilesDatabase might then
// check the mbtiles file based on the version string against the correct spec.

// Keys and predefined values according to MBTiles spec 1.1
// See https://github.com/mapbox/mbtiles-spec/blob/master/1.1/spec.md
//
// required keys
NSString * const kNameKey        = @"name";
NSString * const kTypeKey        = @"type";
NSString * const kVersionKey     = @"version";
NSString * const kDescriptionKey = @"description";
NSString * const kFormatKey      = @"format";

// optional keys
NSString * const kBoundsKey      = @"bounds";

// valid values for 'type'
NSString * const kTypeOverlay    = @"overlay";
NSString * const kTypeBaselayer  = @"baselayer";

// valid values for 'format'
NSString * const kFormatJPEG     = @"jpg";
NSString * const kFormatPNG      = @"png";


#pragma mark -

@interface MBXMBTilesDatabase ()

@property (readwrite, nonatomic) NSURL *url;

@property (readwrite, nonatomic) NSString *name;
@property (readwrite, nonatomic) NSString *type;
@property (readwrite, nonatomic) NSString *version;
@property (readwrite, nonatomic) NSString *description;
@property (readwrite, nonatomic) NSString *format;
@property (readwrite, nonatomic) MKCoordinateRegion mapRegion;
@property (readwrite, nonatomic) NSInteger minimumZ;
@property (readwrite, nonatomic) NSInteger maximumZ;
@property (readwrite, nonatomic) BOOL invalid;

@property (nonatomic) BOOL initializedProperly;

@end


#pragma mark -

@implementation MBXMBTilesDatabase

- (instancetype)initWithMBTilesURL:(NSURL *)mbtilesURL
{
    if (self = [super init])
    {
        _url = mbtilesURL;
        
        NSString *name        = [self sqliteMetadataForName:kNameKey];
        NSString *type        = [self sqliteMetadataForName:kTypeKey];
        NSString *version     = [self sqliteMetadataForName:kVersionKey];
        NSString *description = [self sqliteMetadataForName:kDescriptionKey];
        NSString *format      = [self sqliteMetadataForName:kFormatKey];
        
        if (name && version && description
            && ([type isEqualToString:kTypeOverlay] || [type isEqualToString:kTypeBaselayer])
            && ([format isEqualToString:kFormatJPEG] || [format isEqualToString:kFormatPNG]))
        {
            // Reaching this point means that the specified mbtiles file at mbtilesURL pointed to an sqlite file which had
            // all the required values in its metadata table to pass the MBTiles spec 1.1.
            //
            _name        = name;
            _type        = type;
            _version     = version;
            _description = description;
            _format      = format;
            
            // check if a bounds key exists
            NSString *bounds = [self sqliteMetadataForName:kBoundsKey];
            
            if (bounds)
            {
                // Parse the bounds string and convert it to a map region and boundingMapRect
                double west, south, east, north;
                
                const char *cBounds = [bounds cStringUsingEncoding:NSASCIIStringEncoding];
                if (4 != sscanf(cBounds,"%lf,%lf,%lf,%lf",&west,&south,&east,&north))
                {
                    // This is bad, bounds was supposed to have 4 comma-separated doubles
                    NSLog(@"initWithMBTilesURL: failed to parse the map bounds: %@", bounds);
                    
                    _mapRegion = MKCoordinateRegionForMapRect(MKMapRectNull);
                }
                else
                {
                    // Construct MKCoordinateRegion
                    MKMapRect boundingRect;

                    MKMapPoint nw = MKMapPointForCoordinate(CLLocationCoordinate2DMake(north, west));
                    MKMapPoint se = MKMapPointForCoordinate(CLLocationCoordinate2DMake(south, east));
                    
                    boundingRect.origin = nw;
                    boundingRect.size.width = se.x - nw.x;
                    boundingRect.size.height = se.y - nw.y;
                    
                    _mapRegion = MKCoordinateRegionForMapRect(boundingRect);
                }
            }
            
            // look up minimum and maximum Z from database
            _minimumZ = [self sqliteMinimumForColumn:@"zoom_level"];
            _maximumZ = [self sqliteMaximumForColumn:@"zoom_level"];
            
            _initializedProperly = YES;
        }
        else
        {
            // Reaching this point means the url doesn't point to a valid mbtiles database, so we can't use it.
            //
            self = nil;
        }
    }
    
    return self;
}


- (NSData *)dataForPath:(MKTileOverlayPath)path withError:(NSError **)error
{
    assert(_initializedProperly);
    
    return [self sqliteDataForPath:path];
}

#pragma mark - sqlite stuff

- (NSString *)sqliteMetadataForName:(NSString *)name
{
    NSString *query = [NSString stringWithFormat:@"SELECT value FROM metadata WHERE name='%@';",name];
    NSData *data = [self sqliteDataForSingleColumnQuery:query];
    return data ? [[NSString alloc] initWithBytes:data.bytes length:data.length encoding:NSUTF8StringEncoding] : nil;
}

- (NSData *)sqliteDataForPath:(MKTileOverlayPath)path
{
    NSString *query = [NSString stringWithFormat:@"SELECT tile_data FROM tiles WHERE zoom_level = %ld AND tile_column = %ld AND tile_row = %ld;",(long)path.z,(long)path.x,(long)path.y];
    NSData *data = [self sqliteDataForSingleColumnQuery:query];
    return data;
}

- (NSInteger)sqliteMinimumForColumn:(NSString *)colName
{
    NSString *query = [NSString stringWithFormat:@"SELECT MIN(zoom_level) FROM %@;", colName];
    NSData *data = [self sqliteDataForSingleColumnQuery:query];
    return data ? [[[NSString alloc] initWithBytes:data.bytes length:data.length encoding:NSUTF8StringEncoding] integerValue] : 0;
}

- (NSInteger)sqliteMaximumForColumn:(NSString *)colName
{
    NSString *query = [NSString stringWithFormat:@"SELECT MAX(zoom_level) FROM %@;", colName];
    NSData *data = [self sqliteDataForSingleColumnQuery:query];
    return data ? [[[NSString alloc] initWithBytes:data.bytes length:data.length encoding:NSUTF8StringEncoding] integerValue] : 20;
}

- (NSData *)sqliteDataForSingleColumnQuery:(NSString *)query
{
    // MBXMapKit expects libsqlite to have been compiled with SQLITE_THREADSAFE=2 (multi-thread mode), which means
    // that it can handle its own thread safety as long as you don't attempt to re-use database connections.
    // Since the queries here are all SELECT's, locking for writes shouldn't be an issue.
    // Some relevant sqlite documentation:
    // - http://sqlite.org/faq.html#q5
    // - http://www.sqlite.org/threadsafe.html
    // - http://www.sqlite.org/c3ref/threadsafe.html
    // - http://www.sqlite.org/c3ref/c_config_covering_index_scan.html#sqliteconfigmultithread
    //
    assert(sqlite3_threadsafe()==2);
    
    // Open the database read-only and multi-threaded. The slightly obscure c-style variable names here and below are
    // used to stay consistent with the sqlite documentaion. See http://sqlite.org/c3ref/open.html
    sqlite3 *db;
    int rc;
    NSString *dbPath = [self.url path];
    const char *filename = [dbPath cStringUsingEncoding:NSUTF8StringEncoding];
    rc = sqlite3_open_v2(filename, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, NULL);
    if (rc)
    {
        NSLog(@"Can't open database %@: %s", dbPath, sqlite3_errmsg(db));
        sqlite3_close(db);
        return nil;
    }
    
    // Prepare the query, see http://sqlite.org/c3ref/prepare.html
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
    
    // Evaluate the query, see http://sqlite.org/c3ref/step.html and http://sqlite.org/c3ref/column_blob.html
    NSData *data = nil;
    rc = sqlite3_step(ppStmt);
    if (rc == SQLITE_ROW)
    {
        // The query is supposed to be for exactly one column
        assert(sqlite3_column_count(ppStmt)==1);
        
        // Success!
        data = [NSData dataWithBytes:sqlite3_column_blob(ppStmt, 0) length:sqlite3_column_bytes(ppStmt, 0)];
        
        // Check if any more rows match
        if(sqlite3_step(ppStmt) != SQLITE_DONE)
        {
            // Oops, the query apparently matched more than one row (could also be an error)... not fatal, but not good.
            NSLog(@"Warning, query may match more than one row: %@",query);
        }
    }
    else if (rc == SQLITE_DONE)
    {
        // The query returned no results.
    }
    else if (rc == SQLITE_BUSY)
    {
        // This is bad, but theoretically it should never happen
        NSLog(@"sqlite3_step() returned SQLITE_BUSY. You probably have a concurrency problem.");
    }
    else
    {
        NSLog(@"sqlite3_step() produced an error: %s", sqlite3_errmsg(db));
    }
    
    // Clean up
    sqlite3_finalize(ppStmt);
    sqlite3_close(db);
    return data;
}

@end
