//
//  MBXOfflineMapDownloader.m
//  MBXMapKit
//
//  Created by Will Snook on 3/19/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import <sqlite3.h>
#import "MBXError.h"
#import "MBXOfflineMapDownloader.h"
#import "MBXOfflineMapDatabase.h"


#pragma mark -

@interface MBXOfflineMapDownloader ()

@property (readwrite, nonatomic) NSString *mapID;
@property (readwrite, nonatomic) BOOL metadata;
@property (readwrite, nonatomic) BOOL markers;
@property (readwrite, nonatomic) MBXRasterImageQuality imageQuality;
@property (readwrite, nonatomic) MKCoordinateRegion mapRegion;
@property (readwrite, nonatomic) NSInteger minimumZ;
@property (readwrite, nonatomic) NSInteger maximumZ;
@property (readwrite, nonatomic) MBXOfflineMapDownloaderState state;
@property (readwrite,nonatomic) NSUInteger totalFilesWritten;
@property (readwrite,nonatomic) NSUInteger totalFilesExpectedToWrite;

@property (nonatomic) NSMutableArray *mutableOfflineMapDatabases;
@property (nonatomic) NSString *partialDatabasePath;
@property (nonatomic) NSURL *offlineMapDirectory;

@property (nonatomic) id<MBXOfflineMapDownloaderDelegate> delegate;

@property (nonatomic) NSOperationQueue *backgroundWorkQueue;
@property (nonatomic) NSOperationQueue *sqliteQueue;

@end


#pragma mark -

@implementation MBXOfflineMapDownloader


#pragma mark - API: Shared downloader singleton

+ (MBXOfflineMapDownloader *)sharedOfflineMapDownloader
{
    static id _sharedDownloader = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _sharedDownloader = [[self alloc] init];
    });
    
    return _sharedDownloader;
}


#pragma mark - Initialize and restore saved state from disk

- (id)init
{
    // MBXMapKit expects libsqlite to have been compiled with SQLITE_THREADSAFE=2 (multi-thread mode), which means
    // that it can handle its own thread safety as long as you don't attempt to re-use database connections.
    //
    assert(sqlite3_threadsafe()==2);

    // NOTE: MBXOfflineMapDownloader is designed with the intention that init should be used _only_ by +sharedOfflineMapDownloader.
    // Please use the shared downloader singleton rather than attempting to create your own MBXOfflineMapDownloader objects.
    //
    self = [super init];

    if(self)
    {
        // Make sure the offline map directory exists and that it will be excluded from iCloud backups
        //
        NSFileManager *fm = [NSFileManager defaultManager];
        NSURL *appSupport = [fm URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
        _offlineMapDirectory = [appSupport URLByAppendingPathComponent:@"MBXMapKit/OfflineMaps"];
        if(_offlineMapDirectory)
        {
            NSError *error;
            BOOL result;
            result = [fm createDirectoryAtURL:_offlineMapDirectory withIntermediateDirectories:YES attributes:nil error:&error];
            [_offlineMapDirectory setResourceValues:@{NSURLIsExcludedFromBackupKey:@YES} error:nil];

            //NSLog(@"\n%@\n%@",[_offlineMapDirectory absoluteString],[_offlineMapDirectory resourceValuesForKeys:@[NSURLIsExcludedFromBackupKey] error:nil]);
        }

        // This is where partial offline map databases live (at most 1 at a time!) while their resources are being downloaded
        //
        _partialDatabasePath = [[_offlineMapDirectory URLByAppendingPathComponent:@"newdatabase.partial"] path];
        //NSLog(@"%@",_partialDatabasePath);
        
        // Restore persistent state from disk
        //
        _mutableOfflineMapDatabases = [[NSMutableArray alloc] init];
        NSArray *files = [fm contentsOfDirectoryAtPath:[_offlineMapDirectory absoluteString] error:nil];
        if (files)
        {
            MBXOfflineMapDatabase *db;
            for(NSString *path in files)
            {
                // Find the completed map databases
                //
                if([path hasSuffix:@".complete"])
                {
                    db = [[MBXOfflineMapDatabase alloc] initWithContentsOfFile:path];
                    if(db)
                    {
                        [_mutableOfflineMapDatabases addObject:db];
                    }
                    else
                    {
                        NSLog(@"Error: %@ is not a valid offline map database",path);
                    }
                }
            }
        }

        if([fm fileExistsAtPath:_partialDatabasePath])
        {
            _state = MBXOfflineMapDownloaderStateSuspended;

            NSError *error;
            [self queryWrittenAndExpectedCountsWithError:&error];
            if(error)
            {
                NSLog(@"Error while querying how many files need to be downloaded %@",error);
            }

            //
            // Note that we're not calling offlineMapDownloader:totalFilesExpectedToWrite: because it isn't possible for the
            // delegate to be set yet. If the object that's invoking init by way of sharedOfflineMapDownloader wants to resume
            // the download, it needs to poll the values of state, totalFilesExpectedToWrite, and totalFilesWritten on its own.
            //
        }
        else
        {
            _state = MBXOfflineMapDownloaderStateAvailable;
        }

        // Configure the background and sqlite operation queues as a serial queues
        //
        _backgroundWorkQueue = [[NSOperationQueue alloc] init];
        [_backgroundWorkQueue setMaxConcurrentOperationCount:1];
        _sqliteQueue = [[NSOperationQueue alloc] init];
        [_sqliteQueue setMaxConcurrentOperationCount:1];
    }

    return self;
}


#pragma mark - Implementation: utility functions

- (void)notifyDelegateOfStateChange
{
    assert(![NSThread isMainThread]);

    if([_delegate respondsToSelector:@selector(offlineMapDownloader:stateChangedTo:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [_delegate offlineMapDownloader:self stateChangedTo:_state];
        });
    }
}


- (void)notifyDelegateOfProgress
{
    assert(![NSThread isMainThread]);

    if([_delegate respondsToSelector:@selector(offlineMapDownloader:totalFilesWritten:totalFilesExpectedToWrite:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [_delegate offlineMapDownloader:self totalFilesWritten:_totalFilesWritten totalFilesExpectedToWrite:_totalFilesExpectedToWrite];
        });
    }
}


- (void)notifyDelegateOfCompletionWithOfflineMapDatabase:(MBXOfflineMapDatabase *)offlineMap
{
    assert(![NSThread isMainThread]);

    if([_delegate respondsToSelector:@selector(offlineMapDownloader:didCompleteOfflineMapDatabase:withError:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [_delegate offlineMapDownloader:self didCompleteOfflineMapDatabase:offlineMap withError:nil];
        });
    }
}


- (void)saveDownloadedData:(NSData *)data forURL:(NSURL *)url
{
    assert(![NSThread isMainThread]);

    // How to do the tile blob inserts using blob id's as foreign keys:
    //   sqlite> INSERT INTO data(value) VALUES("foo");
    //   sqlite> INSERT INTO resources VALUES('bar','200',last_insert_rowid());

    _totalFilesWritten += 1;
}


- (MBXOfflineMapDatabase *)completeDatabaseAndInstantiateOfflineMap
{
    assert(![NSThread isMainThread]);

    // TODO: rename the db instead of deleting it

    [_sqliteQueue addOperationWithBlock:^{
        [[NSFileManager defaultManager] removeItemAtPath:_partialDatabasePath error:nil];
    }];
    return nil;
}


- (void)startDownloading
{
    assert(![NSThread isMainThread]);

    // TODO: Prime the download pipeline with URLs from the sqlite db

    for(NSInteger i=_totalFilesWritten; i<_totalFilesExpectedToWrite; i++)
    {
        [_sqliteQueue addOperationWithBlock:^{
            // Do some fake work
            //
            [NSThread sleepForTimeInterval:0.314];
            [self saveDownloadedData:nil forURL:nil];

            // Update the progress
            //
            [self notifyDelegateOfProgress];


            // If all the downloads are done, clean up and notify the delegate
            //
            if(_totalFilesWritten >= _totalFilesExpectedToWrite && _state != MBXOfflineMapDownloaderStateAvailable)
            {
                MBXOfflineMapDatabase *offlineMap = [self completeDatabaseAndInstantiateOfflineMap];
                [self notifyDelegateOfCompletionWithOfflineMapDatabase:offlineMap];

                _state = MBXOfflineMapDownloaderStateAvailable;
                [self notifyDelegateOfStateChange];
            }
        }];
    }
}


#pragma mark - Implementation: sqlite stuff

- (void)queryWrittenAndExpectedCountsWithError:(NSError **)error
{
    // Calculate how many files need to be written in total and how many of them have been written already
    //
    NSString *query = @"SELECT COUNT(url) AS totalFilesExpectedToWrite, (SELECT COUNT(url) FROM resources WHERE status IS NOT NULL) AS totalFilesWritten FROM resources;\n";

    // Open the database
    //
    sqlite3 *db;
    const char *filename = [_partialDatabasePath cStringUsingEncoding:NSUTF8StringEncoding];
    int rc = sqlite3_open_v2(filename, &db, SQLITE_OPEN_READONLY, NULL);
    if (rc)
    {
        // Opening the database failed... something is very wrong.
        //
        if(error != NULL)
        {
            *error = [MBXError errorCannotOpenOfflineMapDatabase:_partialDatabasePath sqliteError:sqlite3_errmsg(db)];
        }
    }
    else
    {
        // Success! First prepare the query...
        //
        const char *zSql = [query cStringUsingEncoding:NSUTF8StringEncoding];
        int nByte = (int)[query lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        sqlite3_stmt *ppStmt;
        const char *pzTail;
        rc = sqlite3_prepare_v2(db, zSql, nByte, &ppStmt, &pzTail);
        if (rc)
        {
            // Preparing the query didn't work.
            //
            if(error)
            {
                *error = [MBXError errorQueryFailedForOfflineMapDatabase:_partialDatabasePath sqliteError:sqlite3_errmsg(db)];
            }
        }
        else
        {
            // Evaluate the query
            //
            rc = sqlite3_step(ppStmt);
            if (rc == SQLITE_ROW && sqlite3_column_count(ppStmt)==2)
            {
                // Success! We got a row with the counts for resource files
                //
                _totalFilesExpectedToWrite = [[NSString stringWithUTF8String:(const char *)sqlite3_column_text(ppStmt, 0)] integerValue];
                _totalFilesWritten = [[NSString stringWithUTF8String:(const char *)sqlite3_column_text(ppStmt, 1)] integerValue];
            }
            else
            {
                // Something unexpected happened.
                //
                if(error)
                {
                    *error = [MBXError errorQueryFailedForOfflineMapDatabase:_partialDatabasePath sqliteError:sqlite3_errmsg(db)];
                }
            }
        }
        sqlite3_finalize(ppStmt);
    }
    sqlite3_close(db);
}


- (void)createDatabaseUsingMetadata:(NSDictionary *)metadata urlArray:(NSArray *)urlStrings withError:(NSError **)error
{
    assert(![NSThread isMainThread]);

    // Build a query to populate the database (map metadata and list of map resource urls)
    //
    NSMutableString *query = [[NSMutableString alloc] init];
    [query appendString:@"PRAGMA foreign_keys=ON;\n"];
    [query appendString:@"BEGIN TRANSACTION;\n"];
    [query appendString:@"CREATE TABLE metadata (name TEXT UNIQUE, value TEXT);\n"];
    [query appendString:@"CREATE TABLE data (id INTEGER PRIMARY KEY, value BLOB);\n"];
    [query appendString:@"CREATE TABLE resources (url TEXT UNIQUE, status TEXT, id INTEGER REFERENCES data);\n"];
    for(NSString *key in metadata) {
        [query appendFormat:@"INSERT INTO \"metadata\" VALUES('%@','%@');\n", key, [metadata valueForKey:key]];
    }
    for(NSString *url in urlStrings)
    {
        [query appendFormat:@"INSERT INTO \"resources\" VALUES('%@',NULL,NULL);\n",url];
    }
    [query appendString:@"COMMIT;"];
    _totalFilesExpectedToWrite = [urlStrings count];
    _totalFilesWritten = 0;


    // Open the database read-write and multi-threaded. The slightly obscure c-style variable names here and below are
    // used to stay consistent with the sqlite documentaion. See http://sqlite.org/c3ref/open.html
    sqlite3 *db;
    int rc;
    const char *filename = [_partialDatabasePath cStringUsingEncoding:NSUTF8StringEncoding];
    rc = sqlite3_open_v2(filename, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, NULL);
    if (rc)
    {
        // Opening the database failed... something is very wrong.
        //
        if(error != NULL)
        {
            *error = [MBXError errorCannotOpenOfflineMapDatabase:_partialDatabasePath sqliteError:sqlite3_errmsg(db)];
        }
        sqlite3_close(db);
    }
    else
    {
        // Success! Creating the database file worked, so now populate the tables we'll need to hold the offline map
        //
        const char *zSql = [query cStringUsingEncoding:NSUTF8StringEncoding];
        char *errmsg;
        sqlite3_exec(db, zSql, NULL, NULL, &errmsg);
        if(error && errmsg != NULL)
        {
            *error = [MBXError errorQueryFailedForOfflineMapDatabase:_partialDatabasePath sqliteError:errmsg];
            sqlite3_free(errmsg);
        }
        sqlite3_close(db);
    }
}


#pragma mark - API: Begin an offline map download

- (void)beginDownloadingMapID:(NSString *)mapID mapRegion:(MKCoordinateRegion)mapRegion minimumZ:(NSInteger)minimumZ maximumZ:(NSInteger)maximumZ
{
    [self beginDownloadingMapID:mapID metadata:YES markers:YES imageQuality:MBXRasterImageQualityFull mapRegion:mapRegion minimumZ:minimumZ maximumZ:maximumZ];
}


- (void)beginDownloadingMapID:(NSString *)mapID metadata:(BOOL)metadata markers:(BOOL)markers mapRegion:(MKCoordinateRegion)mapRegion minimumZ:(NSInteger)minimumZ maximumZ:(NSInteger)maximumZ
{
    [self beginDownloadingMapID:mapID metadata:metadata markers:markers imageQuality:MBXRasterImageQualityFull mapRegion:mapRegion minimumZ:minimumZ maximumZ:maximumZ];
}


- (void)beginDownloadingMapID:(NSString *)mapID metadata:(BOOL)metadata markers:(BOOL)markers imageQuality:(MBXRasterImageQuality)imageQuality mapRegion:(MKCoordinateRegion)mapRegion minimumZ:(NSInteger)minimumZ maximumZ:(NSInteger)maximumZ
{
    assert(_state == MBXOfflineMapDownloaderStateAvailable);

    [_backgroundWorkQueue addOperationWithBlock:^{

        // Start a download job to retrieve all the resources needed for using the specified map offline
        //
        _mapID = mapID;
        _metadata = metadata;
        _markers = markers;
        _imageQuality = imageQuality;
        _mapRegion = mapRegion;
        _minimumZ = minimumZ;
        _maximumZ = maximumZ;
        _state = MBXOfflineMapDownloaderStateRunning;
        [self notifyDelegateOfStateChange];

        //
        // TODO: Make this real...
        //       - Calculate the list of tiles to be requested
        //       - Start the thing which keeps track of the background downloads
        //
        NSDictionary *metadataDictionary =
        @{
          @"mapID": mapID,
          @"metadata" : metadata?@"YES":@"NO",
          @"markers" : markers?@"YES":@"NO",
          @"imageQuality" : [NSString stringWithFormat:@"%ld",(long)imageQuality],
          @"region_latitude" : [NSString stringWithFormat:@"%.8f",mapRegion.center.latitude],
          @"region_longitude" : [NSString stringWithFormat:@"%.8f",mapRegion.center.longitude],
          @"region_latitude_delta" : [NSString stringWithFormat:@"%.8f",mapRegion.span.latitudeDelta],
          @"region_longitude_delta" : [NSString stringWithFormat:@"%.8f",mapRegion.span.longitudeDelta],
          @"minimumZ" : [NSString stringWithFormat:@"%ld",(long)minimumZ],
          @"maximumZ" : [NSString stringWithFormat:@"%ld",(long)maximumZ]
          };

        NSArray *urlStrings =
        @[
          @"https://a.tiles.mapbox.com/v3/examples.map-pgygbwdm.json",
          @"https://a.tiles.mapbox.com/v3/examples.map-pgygbwdm/markers.geojson",
          @"https://a.tiles.mapbox.com/v3/marker/pin-m-swimming+f5c272@2x.png",
          @"https://a.tiles.mapbox.com/v3/examples.map-pgygbwdm/15/5277/12755@2x.png",
          @"https://a.tiles.mapbox.com/v3/examples.map-pgygbwdm/15/5277/12756@2x.png",
          @"https://a.tiles.mapbox.com/v3/examples.map-pgygbwdm/15/5277/12757@2x.png",
          @"https://a.tiles.mapbox.com/v3/examples.map-pgygbwdm/15/5277/12758@2x.png",
          @"https://a.tiles.mapbox.com/v3/examples.map-pgygbwdm/15/5278/12755@2x.png",
          @"https://a.tiles.mapbox.com/v3/examples.map-pgygbwdm/15/5278/12756@2x.png",
          @"https://a.tiles.mapbox.com/v3/examples.map-pgygbwdm/15/5278/12757@2x.png",
          @"https://a.tiles.mapbox.com/v3/examples.map-pgygbwdm/15/5278/12758@2x.png",
          @"https://a.tiles.mapbox.com/v3/examples.map-pgygbwdm/15/5279/12755@2x.png",
          @"https://a.tiles.mapbox.com/v3/examples.map-pgygbwdm/15/5279/12756@2x.png",
          @"https://a.tiles.mapbox.com/v3/examples.map-pgygbwdm/15/5279/12757@2x.png",
          @"https://a.tiles.mapbox.com/v3/examples.map-pgygbwdm/15/5279/12758@2x.png"
          ];

        NSError *error;
        [self createDatabaseUsingMetadata:metadataDictionary urlArray:urlStrings withError:&error];
        if(error)
        {
            // Creating the database failed for some reason, so clean up and change the state back to available
            //
            _state = MBXOfflineMapDownloaderStateCanceling;
            [self notifyDelegateOfStateChange];

            if([_delegate respondsToSelector:@selector(offlineMapDownloader:didCompleteOfflineMapDatabase:withError:)])
            {
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    [_delegate offlineMapDownloader:self didCompleteOfflineMapDatabase:nil withError:error];
                });
            }

            [_sqliteQueue cancelAllOperations];
            [_sqliteQueue addOperationWithBlock:^{
                [[NSFileManager defaultManager] removeItemAtPath:_partialDatabasePath error:nil];
            }];

            _state = MBXOfflineMapDownloaderStateAvailable;
            [self notifyDelegateOfStateChange];
        }


        // Update the delegate with the initial count of files to be downloaded and start downloading
        //
        if([_delegate respondsToSelector:@selector(offlineMapDownloader:totalFilesExpectedToWrite:)])
        {
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [_delegate offlineMapDownloader:self totalFilesExpectedToWrite:_totalFilesExpectedToWrite];
            });
        }
        [self startDownloading];

    }];
}


#pragma mark - API: Control an in-progress offline map download

- (void)cancel
{
    if(_state == MBXOfflineMapDownloaderStateCanceling)
    {
        NSLog(@"Attempting to cancel while the offline map downloader state is 'canceling'. Concurrency problem?");
    }
    else if(_state == MBXOfflineMapDownloaderStateAvailable)
    {
        NSLog(@"Attempting to cancel while the offline map downloader state is 'available'. Concurrency problem?");
    }
    else
    {
        // Stop a download job and discard the associated files
        //
        [_backgroundWorkQueue addOperationWithBlock:^{
            _state = MBXOfflineMapDownloaderStateCanceling;
            [self notifyDelegateOfStateChange];

            [_sqliteQueue cancelAllOperations];
            [_sqliteQueue addOperationWithBlock:^{
                [[NSFileManager defaultManager] removeItemAtPath:_partialDatabasePath error:nil];
            }];

            if([_delegate respondsToSelector:@selector(offlineMapDownloader:didCompleteOfflineMapDatabase:withError:)])
            {
                NSError *canceled = [MBXError errorWithCode:MBXMapKitErrorDownloadingCanceled reason:@"The download job was canceled" description:@"Download canceled"];
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    [_delegate offlineMapDownloader:self didCompleteOfflineMapDatabase:nil withError:canceled];
                });
            }

            _state = MBXOfflineMapDownloaderStateAvailable;
            [self notifyDelegateOfStateChange];
        }];
    }
}


- (void)resume
{
    assert(_state == MBXOfflineMapDownloaderStateSuspended);

    // Resume a previously suspended download job
    //
    [_backgroundWorkQueue addOperationWithBlock:^{
        [self startDownloading];
        _state = MBXOfflineMapDownloaderStateRunning;
        [self notifyDelegateOfStateChange];
    }];
}


- (void)suspend
{
    assert(_state == MBXOfflineMapDownloaderStateRunning);

    // Stop a download job, preserving the necessary state to resume later
    //
    [_backgroundWorkQueue addOperationWithBlock:^{
        [_sqliteQueue cancelAllOperations];
        _state = MBXOfflineMapDownloaderStateSuspended;
        [self notifyDelegateOfStateChange];
    }];
}


#pragma mark - API: Access or delete completed offline map databases on disk

- (NSArray *)offlineMapDatabases
{
    // Return an array with offline map database objects representing each of the *complete* map databases on disk
    //
    return [NSArray arrayWithArray:_mutableOfflineMapDatabases];
}


- (void)removeOfflineMapDatabase:(MBXOfflineMapDatabase *)offlineMapDatabase
{
    // Mark the offline map object as invalid in case there are any references to it still floating around
    //
    [offlineMapDatabase invalidate];

    // If this assert fails, an MBXOfflineMapDatabase object has somehow been initialized with a database path which is not
    // inside of the directory for completed ofline map databases. That should definitely not be happening, and we should definitely
    // not proceed to recursively remove whatever the path string actually is pointed at.
    //
    assert([offlineMapDatabase.path hasPrefix:[_offlineMapDirectory absoluteString]]);

    // Remove the offline map object from the array and delete it's backing database
    //
    [_mutableOfflineMapDatabases removeObject:offlineMapDatabase];

    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:offlineMapDatabase.path error:&error];
    if(error)
    {
        NSLog(@"There was an error while attempting to delete an offline map database: %@", error);
    }
}


@end
