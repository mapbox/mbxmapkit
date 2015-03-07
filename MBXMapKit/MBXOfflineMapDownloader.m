//
//  MBXOfflineMapDownloader.m
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

#import "MBXMapKit.h"

#import <sqlite3.h>

#pragma mark - Private API for creating verbose errors

@interface NSError (MBXError)

+ (NSError *)mbx_errorWithCode:(NSInteger)code reason:(NSString *)reason description:(NSString *)description;
+ (NSError *)mbx_errorCannotOpenOfflineMapDatabase:(NSString *)path sqliteError:(const char *)sqliteError;
+ (NSError *)mbx_errorQueryFailedForOfflineMapDatabase:(NSString *)path sqliteError:(const char *)sqliteError;

@end


#pragma mark - Private API for cooperating with MBXRasterTileOverlay

@interface MBXRasterTileOverlay ()

+ (NSString *)qualityExtensionForImageQuality:(MBXRasterImageQuality)imageQuality;
+ (NSURL *)markerIconURLForSize:(NSString *)size symbol:(NSString *)symbol color:(NSString *)color;

@end


#pragma mark - Private API for cooperating with MBXOfflineMapDatabase

@interface MBXOfflineMapDatabase ()

@property (readonly, nonatomic) NSString *path;

- (instancetype)initWithContentsOfFile:(NSString *)path;
- (void)invalidate;

@end


#pragma mark -

@interface MBXOfflineMapDownloader ()

@property (readwrite, nonatomic) NSString *uniqueID;
@property (readwrite, nonatomic) NSString *mapID;
@property (readwrite, nonatomic) BOOL includesMetadata;
@property (readwrite, nonatomic) BOOL includesMarkers;
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

@property (nonatomic) NSOperationQueue *backgroundWorkQueue;
@property (nonatomic) NSOperationQueue *sqliteQueue;
@property (nonatomic) NSURLSession *dataSession;
@property (nonatomic) NSInteger activeDataSessionTasks;

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

- (instancetype)init
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
        // Calculate the path in Application Support for storing offline maps
        //
        NSFileManager *fm = [NSFileManager defaultManager];
        NSURL *appSupport = [fm URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
        _offlineMapDirectory = [appSupport URLByAppendingPathComponent:@"MBXMapKit/OfflineMaps"];

        // Make sure the offline map directory exists
        //
        NSError *error;
        [fm createDirectoryAtURL:_offlineMapDirectory withIntermediateDirectories:YES attributes:nil error:&error];
        if(error)
        {
            NSLog(@"There was an error with creating the offline map directory: %@", error);
            error = nil;
        }

        // Figure out if the offline map directory already has a value for NSURLIsExcludedFromBackupKey. If so,
        // then leave that value alone. Otherwise, set a default value to exclude offline maps from backups.
        //
        NSNumber *excluded;
        [_offlineMapDirectory getResourceValue:&excluded forKey:NSURLIsExcludedFromBackupKey error:&error];
        if(error)
        {
            NSLog(@"There was an error with checking the offline map directory's resource values: %@", error);
            error = nil;
        }
        if(excluded != nil)
        {
            _offlineMapsAreExcludedFromBackup = [excluded boolValue];
        }
        else
        {
            [self setOfflineMapsAreExcludedFromBackup:YES];
        }


        // This is where partial offline map databases live (at most 1 at a time!) while their resources are being downloaded
        //
        _partialDatabasePath = [[_offlineMapDirectory URLByAppendingPathComponent:@"newdatabase.partial"] path];


        // Restore persistent state from disk
        //
        _mutableOfflineMapDatabases = [[NSMutableArray alloc] init];
        error = nil;
        NSArray *files = [fm contentsOfDirectoryAtPath:[_offlineMapDirectory path] error:&error];
        if(error)
        {
            NSLog(@"There was an error with listing the contents of the offline map directory: %@", error);
        }
        if (files)
        {
            MBXOfflineMapDatabase *db;
            for(NSString *path in files)
            {
                // Find the completed map databases
                //
                if([path hasSuffix:@".complete"])
                {
                    db = [[MBXOfflineMapDatabase alloc] initWithContentsOfFile:[[_offlineMapDirectory URLByAppendingPathComponent:path] path]];
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
            [self sqliteQueryWrittenAndExpectedCountsWithError:&error];
            if(error)
            {
                NSLog(@"Error while querying how many files need to be downloaded %@",error);
            }
            else if(_totalFilesWritten >= _totalFilesExpectedToWrite)
            {
                // This isn't good... the offline map database is completely downloaded, but it's still in the location for
                // a download in progress.
                NSLog(@"Something strange happened. While restoring a supposedly partial offline map download from disk, init found that %ld of %ld urls are complete.",(long)_totalFilesWritten,(long)_totalFilesExpectedToWrite);
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

        // Configure the download session
        //
        [self setUpNewDataSession];
    }

    return self;
}

- (void)setOfflineMapsAreExcludedFromBackup:(BOOL)offlineMapsAreExcludedFromBackup
{
    NSError *error;
    NSNumber *boolNumber = offlineMapsAreExcludedFromBackup ? @YES : @NO;
    [_offlineMapDirectory setResourceValue:boolNumber forKey:NSURLIsExcludedFromBackupKey error:&error];
    if(error)
    {
        NSLog(@"There was an error setting NSURLIsExcludedFromBackupKey on the offline map directory: %@",error);
    }
    else
    {
        _offlineMapsAreExcludedFromBackup = offlineMapsAreExcludedFromBackup;
    }
}

- (void)setUpNewDataSession
{
    // Create a new NSURLDataSession. This is necessary after a call to invalidateAndCancel
    //
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.allowsCellularAccess = YES;
    config.HTTPMaximumConnectionsPerHost = 4;
    config.URLCache = [NSURLCache sharedURLCache];
    config.HTTPAdditionalHeaders = @{ @"User-Agent" : [MBXMapKit userAgent] };
    _dataSession = [NSURLSession sessionWithConfiguration:config];
    _activeDataSessionTasks = 0;
}


#pragma mark - Delegate Notifications

- (void)notifyDelegateOfStateChange
{
    assert(![NSThread isMainThread]);

    if([_delegate respondsToSelector:@selector(offlineMapDownloader:stateChangedTo:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate offlineMapDownloader:self stateChangedTo:_state];
        });
    }
}


- (void)notifyDelegateOfInitialCount
{
    if([_delegate respondsToSelector:@selector(offlineMapDownloader:totalFilesExpectedToWrite:)])
    {
        // Update the delegate with the file count so it can display a progress indicator
        //
        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate offlineMapDownloader:self totalFilesExpectedToWrite:_totalFilesExpectedToWrite];
        });
    }
}


- (void)notifyDelegateOfProgress
{
    assert(![NSThread isMainThread]);

    if([_delegate respondsToSelector:@selector(offlineMapDownloader:totalFilesWritten:totalFilesExpectedToWrite:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate offlineMapDownloader:self totalFilesWritten:_totalFilesWritten totalFilesExpectedToWrite:_totalFilesExpectedToWrite];
        });
    }
}


- (void)notifyDelegateOfNetworkConnectivityError:(NSError *)error
{
    assert(![NSThread isMainThread]);

    if([_delegate respondsToSelector:@selector(offlineMapDownloader:didEncounterRecoverableError:)])
    {
        NSError *networkError = [NSError mbx_errorWithCode:MBXMapKitErrorCodeURLSessionConnectivity reason:[error localizedFailureReason] description:[error localizedDescription]];

        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate offlineMapDownloader:self didEncounterRecoverableError:networkError];
        });
    }
}


- (void)notifyDelegateOfSqliteError:(NSError *)error
{
    assert(![NSThread isMainThread]);

    if([_delegate respondsToSelector:@selector(offlineMapDownloader:didEncounterRecoverableError:)])
    {
        NSError *networkError = [NSError mbx_errorWithCode:MBXMapKitErrorCodeOfflineMapSqlite reason:[error localizedFailureReason] description:[error localizedDescription]];

        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate offlineMapDownloader:self didEncounterRecoverableError:networkError];
        });
    }
}


- (void)notifyDelegateOfHTTPStatusError:(NSInteger)status url:(NSURL *)url
{
    assert(![NSThread isMainThread]);

    if([_delegate respondsToSelector:@selector(offlineMapDownloader:didEncounterRecoverableError:)])
    {
        NSString *reason = [NSString stringWithFormat:@"HTTP status %li was received for %@", (long)status,[url absoluteString]];
        NSError *statusError = [NSError mbx_errorWithCode:MBXMapKitErrorCodeHTTPStatus reason:reason description:@"HTTP status error"];

        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate offlineMapDownloader:self didEncounterRecoverableError:statusError];
        });
    }
}


- (void)notifyDelegateOfCompletionWithOfflineMapDatabase:(MBXOfflineMapDatabase *)offlineMap withError:(NSError *)error
{
    assert(![NSThread isMainThread]);

    if([_delegate respondsToSelector:@selector(offlineMapDownloader:didCompleteOfflineMapDatabase:withError:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate offlineMapDownloader:self didCompleteOfflineMapDatabase:offlineMap withError:error];
        });
    }
}


#pragma mark - Implementation: download urls


- (MBXOfflineMapDatabase *)completeDatabaseAndInstantiateOfflineMapWithError:(NSError **)error
{
    assert(![NSThread isMainThread]);

    // Rename the file using a unique prefix
    //
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    CFStringRef uuidString = CFUUIDCreateString(kCFAllocatorDefault, uuid);
    NSString *newFilename = [NSString stringWithFormat:@"%@.complete",uuidString];
    NSString *newPath = [[_offlineMapDirectory URLByAppendingPathComponent:newFilename] path];
    CFRelease(uuidString);
    CFRelease(uuid);
    [[NSFileManager defaultManager] moveItemAtPath:_partialDatabasePath toPath:newPath error:error];

    // If the move worked, instantiate and return offline map database
    //
    if(error && *error)
    {
        return nil;
    }
    else
    {
        return [[MBXOfflineMapDatabase alloc] initWithContentsOfFile:newPath];
    }
}


- (void)startDownloading
{
    assert(![NSThread isMainThread]);

    [_sqliteQueue addOperationWithBlock:^{
        NSError *error;
        NSArray *urls = [self sqliteReadArrayOfOfflineMapURLsToBeDownloadLimit:30 withError:&error];
        if(error)
        {
            NSLog(@"Error while reading offline map urls: %@",error);
        }
        else
        {
            for(NSURL *url in urls)
            {
                NSURLSessionDataTask *task;
                NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60];
                _activeDataSessionTasks += 1;
                task = [_dataSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
                {
                    if(error  && _state == MBXOfflineMapDownloaderStateRunning)
                    {
                        // We got a session level error which probably indicates a connectivity problem such as airplane mode.
                        // Notify the delegate.
                        //
                        [self notifyDelegateOfNetworkConnectivityError:error];
                    }
                    if(!error  && _state == MBXOfflineMapDownloaderStateRunning)
                    {
                        if ([response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse *)response).statusCode != 200)
                        {
                            // This url didn't work. For now, use the primitive error handling method of notifying the delegate and
                            // continuing to request the url (this will eventually cycle back through the download queue since we're
                            // not marking the url as done in the database).
                            //
                            [self notifyDelegateOfHTTPStatusError:((NSHTTPURLResponse *)response).statusCode url:response.URL];
                        }
                        else
                        {
                            // Since the URL was successfully retrieved, save the data
                            //
                            [self sqliteSaveDownloadedData:data forURL:url];
                        }
                    }
                }];
                [task resume];

                // This is the last line of the for loop
            }
        }
    }];

}


#pragma mark - Implementation: sqlite stuff

- (void)sqliteSaveDownloadedData:(NSData *)data forURL:(NSURL *)url
{
    assert(![NSThread isMainThread]);
    assert(_activeDataSessionTasks > 0);

    [_sqliteQueue addOperationWithBlock:^{

        // Bail out if the state has changed to canceling, suspended, or available
        //
        if(_state != MBXOfflineMapDownloaderStateRunning)
        {
            return;
        }

        // Open the database read-write and multi-threaded. The slightly obscure c-style variable names here and below are
        // used to stay consistent with the sqlite documentaion.
        NSError *error;
        sqlite3 *db;
        int rc;
        const char *filename = [_partialDatabasePath cStringUsingEncoding:NSUTF8StringEncoding];
        rc = sqlite3_open_v2(filename, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, NULL);
        if (rc)
        {
            // Opening the database failed... something is very wrong.
            //
            error = [NSError mbx_errorCannotOpenOfflineMapDatabase:_partialDatabasePath sqliteError:sqlite3_errmsg(db)];
        }
        else
        {
            // Creating the database file worked, so now start an atomic commit
            //
            NSMutableString *query = [[NSMutableString alloc] init];
            [query appendString:@"PRAGMA foreign_keys=ON;\n"];
            [query appendString:@"BEGIN TRANSACTION;\n"];
            const char *zSql = [query cStringUsingEncoding:NSUTF8StringEncoding];
            char *errmsg;
            sqlite3_exec(db, zSql, NULL, NULL, &errmsg);
            if(errmsg)
            {
                error = [NSError mbx_errorQueryFailedForOfflineMapDatabase:_partialDatabasePath sqliteError:errmsg];
                sqlite3_free(errmsg);
            }
            else
            {
                // Continue by inserting an image blob into the data table
                //
                NSString *query2 = @"INSERT INTO data(value) VALUES(?);";
                const char *zSql2 = [query2 cStringUsingEncoding:NSUTF8StringEncoding];
                int nByte2 = (int)[query2 lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
                sqlite3_stmt *ppStmt2;
                const char *pzTail2;
                BOOL successfulBlobInsert = NO;
                if(sqlite3_prepare_v2(db, zSql2, nByte2, &ppStmt2, &pzTail2) == SQLITE_OK)
                {
                    if(sqlite3_bind_blob(ppStmt2, 1, [data bytes], (int)[data length], SQLITE_TRANSIENT) == SQLITE_OK)
                    {
                        if(sqlite3_step(ppStmt2) == SQLITE_DONE)
                        {
                            successfulBlobInsert = YES;
                        }
                    }
                }
                if(!successfulBlobInsert)
                {
                    error = [NSError mbx_errorQueryFailedForOfflineMapDatabase:_partialDatabasePath sqliteError:sqlite3_errmsg(db)];
                }
                sqlite3_finalize(ppStmt2);

                // Finish up by updating the url in the resources table with status and the blob id, then close out the commit
                //
                if(!error)
                {
                    query  = [[NSMutableString alloc] init];
                    [query appendFormat:@"UPDATE resources SET status=200,id=last_insert_rowid() WHERE url='%@';\n",[url absoluteString]];
                    [query appendString:@"COMMIT;"];
                    const char *zSql3 = [query cStringUsingEncoding:NSUTF8StringEncoding];
                    sqlite3_exec(db, zSql3, NULL, NULL, &errmsg);
                    if(errmsg)
                    {
                        error = [NSError mbx_errorQueryFailedForOfflineMapDatabase:_partialDatabasePath sqliteError:errmsg];
                        sqlite3_free(errmsg);
                    }
                }

            }
        }
        sqlite3_close(db);

        if(error)
        {
            // Oops, that didn't work. Notify the delegate.
            //
            [self notifyDelegateOfSqliteError:error];
        }
        else
        {
            // Update the progress
            //
            _totalFilesWritten += 1;
            [self notifyDelegateOfProgress];

            // If all the downloads are done, clean up and notify the delegate
            //
            if(_totalFilesWritten >= _totalFilesExpectedToWrite)
            {
                if(_state == MBXOfflineMapDownloaderStateRunning)
                {
                    // This is what to do when we've downloaded all the files
                    //
                    MBXOfflineMapDatabase *offlineMap = [self completeDatabaseAndInstantiateOfflineMapWithError:&error];
                    if(offlineMap && !error) {
                        [_mutableOfflineMapDatabases addObject:offlineMap];
                    }
                    [self notifyDelegateOfCompletionWithOfflineMapDatabase:offlineMap withError:error];

                    _state = MBXOfflineMapDownloaderStateAvailable;
                    [self notifyDelegateOfStateChange];
                }
            }
        }

        // If this was the last of a batch of urls in the data session's download queue, and there are more urls
        // to be downloaded, get another batch of urls from the database and keep working.
        //
        if(_activeDataSessionTasks > 0)
        {
            _activeDataSessionTasks -= 1;
        }
        if(_activeDataSessionTasks == 0 && _totalFilesWritten < _totalFilesExpectedToWrite)
        {
            [self startDownloading];
        }
    }];
}


- (NSArray *)sqliteReadArrayOfOfflineMapURLsToBeDownloadLimit:(NSInteger)limit withError:(NSError **)error
{
    assert(![NSThread isMainThread]);

    // Read up to limit undownloaded urls from the offline map database
    //
    NSMutableArray *urlArray = [[NSMutableArray alloc] init];
    NSString *query = [NSString stringWithFormat:@"SELECT url FROM resources WHERE status IS NULL LIMIT %ld;\n",(long)limit];

    // Open the database
    //
    sqlite3 *db;
    const char *filename = [_partialDatabasePath cStringUsingEncoding:NSUTF8StringEncoding];
    int rc = sqlite3_open_v2(filename, &db, SQLITE_OPEN_READONLY, NULL);
    if (rc)
    {
        // Opening the database failed... something is very wrong.
        //
        if(error)
        {
            *error = [NSError mbx_errorCannotOpenOfflineMapDatabase:_partialDatabasePath sqliteError:sqlite3_errmsg(db)];
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
                *error = [NSError mbx_errorQueryFailedForOfflineMapDatabase:_partialDatabasePath sqliteError:sqlite3_errmsg(db)];
            }
        }
        else
        {
            // Evaluate the query
            //
            BOOL keepGoing = YES;
            while(keepGoing)
            {
                rc = sqlite3_step(ppStmt);
                if(rc == SQLITE_ROW && sqlite3_column_count(ppStmt)==1)
                {
                    // Success! We got a URL row, so add it to the array
                    //
                    [urlArray addObject:[NSURL URLWithString:[NSString stringWithUTF8String:(const char *)sqlite3_column_text(ppStmt, 0)]]];
                }
                else if(rc == SQLITE_DONE)
                {
                    keepGoing = NO;
                }
                else
                {
                    // Something unexpected happened.
                    //
                    keepGoing = NO;
                    if(error)
                    {
                        *error = [NSError mbx_errorQueryFailedForOfflineMapDatabase:_partialDatabasePath sqliteError:sqlite3_errmsg(db)];
                    }
                }
            }
        }
        sqlite3_finalize(ppStmt);
    }
    sqlite3_close(db);

    return [NSArray arrayWithArray:urlArray];
}


- (BOOL)sqliteQueryWrittenAndExpectedCountsWithError:(NSError **)error
{
    // NOTE: Unlike most of the sqlite code, this method is written with the expectation that it can and will be called on the main
    //       thread as part of init. This is also meant to be used in other contexts throught the normal serial operation queue.

    // Calculate how many files need to be written in total and how many of them have been written already
    //
    NSString *query = @"SELECT COUNT(url) AS totalFilesExpectedToWrite, (SELECT COUNT(url) FROM resources WHERE status IS NOT NULL) AS totalFilesWritten FROM resources;\n";

    BOOL success = NO;
    // Open the database
    //
    sqlite3 *db;
    const char *filename = [_partialDatabasePath cStringUsingEncoding:NSUTF8StringEncoding];
    int rc = sqlite3_open_v2(filename, &db, SQLITE_OPEN_READONLY, NULL);
    if (rc)
    {
        // Opening the database failed... something is very wrong.
        //
        if(error)
        {
            *error = [NSError mbx_errorCannotOpenOfflineMapDatabase:_partialDatabasePath sqliteError:sqlite3_errmsg(db)];
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
                *error = [NSError mbx_errorQueryFailedForOfflineMapDatabase:_partialDatabasePath sqliteError:sqlite3_errmsg(db)];
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
                success = YES;
            }
            else
            {
                // Something unexpected happened.
                //
                if(error)
                {
                    *error = [NSError mbx_errorQueryFailedForOfflineMapDatabase:_partialDatabasePath sqliteError:sqlite3_errmsg(db)];
                }
            }
        }
        sqlite3_finalize(ppStmt);
    }
    sqlite3_close(db);

    return success;
}


- (BOOL)sqliteCreateDatabaseUsingMetadata:(NSDictionary *)metadata urlArray:(NSArray *)urlStrings withError:(NSError **)error
{
    assert(![NSThread isMainThread]);
    BOOL success = NO;

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
    // used to stay consistent with the sqlite documentaion.
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
            *error = [NSError mbx_errorCannotOpenOfflineMapDatabase:_partialDatabasePath sqliteError:sqlite3_errmsg(db)];
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
            *error = [NSError mbx_errorQueryFailedForOfflineMapDatabase:_partialDatabasePath sqliteError:errmsg];
            sqlite3_free(errmsg);
        }
        sqlite3_close(db);
        success = YES;
    }
    return success;
}


#pragma mark - API: Begin an offline map download

- (void)beginDownloadingMapID:(NSString *)mapID mapRegion:(MKCoordinateRegion)mapRegion minimumZ:(NSInteger)minimumZ maximumZ:(NSInteger)maximumZ
{
    [self beginDownloadingMapID:mapID mapRegion:mapRegion minimumZ:minimumZ maximumZ:maximumZ includeMetadata:YES includeMarkers:YES imageQuality:MBXRasterImageQualityFull];
}


- (void)beginDownloadingMapID:(NSString *)mapID mapRegion:(MKCoordinateRegion)mapRegion minimumZ:(NSInteger)minimumZ maximumZ:(NSInteger)maximumZ includeMetadata:(BOOL)includeMetadata includeMarkers:(BOOL)includeMarkers
{
    [self beginDownloadingMapID:mapID mapRegion:mapRegion minimumZ:minimumZ maximumZ:maximumZ includeMetadata:includeMetadata includeMarkers:includeMarkers imageQuality:MBXRasterImageQualityFull];
}


- (void)beginDownloadingMapID:(NSString *)mapID mapRegion:(MKCoordinateRegion)mapRegion minimumZ:(NSInteger)minimumZ maximumZ:(NSInteger)maximumZ includeMetadata:(BOOL)includeMetadata includeMarkers:(BOOL)includeMarkers imageQuality:(MBXRasterImageQuality)imageQuality
{
    assert(_state == MBXOfflineMapDownloaderStateAvailable);

    [self setUpNewDataSession];

    [_backgroundWorkQueue addOperationWithBlock:^{

        // Start a download job to retrieve all the resources needed for using the specified map offline
        //
        _uniqueID = [[NSUUID UUID] UUIDString];
        _mapID = mapID;
        _includesMetadata = includeMetadata;
        _includesMarkers = includeMarkers;
        _imageQuality = imageQuality;
        _mapRegion = mapRegion;
        _minimumZ = minimumZ;
        _maximumZ = maximumZ;
        _state = MBXOfflineMapDownloaderStateRunning;
        [self notifyDelegateOfStateChange];

        NSDictionary *metadataDictionary =
        @{
          @"uniqueID": _uniqueID,
          @"mapID": mapID,
          @"includesMetadata" : includeMetadata?@"YES":@"NO",
          @"includesMarkers" : includeMarkers?@"YES":@"NO",
          @"imageQuality" : [NSString stringWithFormat:@"%ld",(long)imageQuality],
          @"region_latitude" : [NSString stringWithFormat:@"%.8f",mapRegion.center.latitude],
          @"region_longitude" : [NSString stringWithFormat:@"%.8f",mapRegion.center.longitude],
          @"region_latitude_delta" : [NSString stringWithFormat:@"%.8f",mapRegion.span.latitudeDelta],
          @"region_longitude_delta" : [NSString stringWithFormat:@"%.8f",mapRegion.span.longitudeDelta],
          @"minimumZ" : [NSString stringWithFormat:@"%ld",(long)minimumZ],
          @"maximumZ" : [NSString stringWithFormat:@"%ld",(long)maximumZ]
          };


        NSMutableArray *urls = [[NSMutableArray alloc] init];

        // Include URLs for the metadata and markers json if applicable
        //
        if(includeMetadata)
        {
            [urls addObject:[NSString stringWithFormat:@"https://a.tiles.mapbox.com/v4/%@.json?secure%@",
                                mapID,
                                [@"&access_token=" stringByAppendingString:[MBXMapKit accessToken]]]];
        }
        if(includeMarkers)
        {
            [urls addObject:[NSString stringWithFormat:@"https://a.tiles.mapbox.com/v4/%@/features.json%@",
                                mapID,
                                [@"?access_token=" stringByAppendingString:[MBXMapKit accessToken]]]];
        }

        // Loop through the zoom levels and lat/lon bounds to generate a list of urls which should be included in the offline map
        //
        CLLocationDegrees minLat = mapRegion.center.latitude - (mapRegion.span.latitudeDelta / 2.0);
        CLLocationDegrees maxLat = minLat + mapRegion.span.latitudeDelta;
        CLLocationDegrees minLon = mapRegion.center.longitude - (mapRegion.span.longitudeDelta / 2.0);
        CLLocationDegrees maxLon = minLon + mapRegion.span.longitudeDelta;
        NSUInteger minX;
        NSUInteger maxX;
        NSUInteger minY;
        NSUInteger maxY;
        NSUInteger tilesPerSide;
        for(NSUInteger zoom = minimumZ; zoom <= maximumZ; zoom++)
        {
            tilesPerSide = pow(2.0, zoom);
            minX = floor(((minLon + 180.0) / 360.0) * tilesPerSide);
            maxX = floor(((maxLon + 180.0) / 360.0) * tilesPerSide);
            minY = floor((1.0 - (logf(tanf(maxLat * M_PI / 180.0) + 1.0 / cosf(maxLat * M_PI / 180.0)) / M_PI)) / 2.0 * tilesPerSide);
            maxY = floor((1.0 - (logf(tanf(minLat * M_PI / 180.0) + 1.0 / cosf(minLat * M_PI / 180.0)) / M_PI)) / 2.0 * tilesPerSide);
            for(NSUInteger x=minX; x<=maxX; x++)
            {
                for(NSUInteger y=minY; y<=maxY; y++)
                {
                    [urls addObject:[NSString stringWithFormat:@"https://a.tiles.mapbox.com/v4/%@/%ld/%ld/%ld%@.%@%@",
                                     mapID,
                                     (long)zoom,
                                     (long)x,
                                     (long)y,
#if TARGET_OS_IPHONE
                                     [[UIScreen mainScreen] scale] > 1.0 ? @"@2x" : @"",
#else
                                     // Making this smart enough to handle a Retina MacBook with a normal dpi external display
                                     // is complicated. For now, just default to @1x images and a 1.0 scale.
                                     //
                                     @"",
#endif
                                     [MBXRasterTileOverlay qualityExtensionForImageQuality:_imageQuality],
                                     [@"?access_token=" stringByAppendingString:[MBXMapKit accessToken]]
                                     ]
                     ];
                }
            }
        }


        // Determine if we need to add marker icon urls (i.e. parse markers.geojson/features.json), and if so, add them
        //
        if(includeMarkers)
        {
            NSURL *geojson = [NSURL URLWithString:[NSString stringWithFormat:@"https://a.tiles.mapbox.com/v4/%@/features.json%@",
                mapID,
                [@"?access_token=" stringByAppendingString:[MBXMapKit accessToken]]]];

            NSURLSessionDataTask *task;
            NSURLRequest *request = [NSURLRequest requestWithURL:geojson cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60];
            task = [_dataSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
            {
                if(error)
                {
                    // We got a session level error which probably indicates a connectivity problem such as airplane mode.
                    // Since we must fetch and parse markers.geojson/features.json in order to determine which marker icons need to be
                    // added to the list of urls to download, the lack of network connectivity is a non-recoverable error
                    // here.
                    //
                    [self notifyDelegateOfNetworkConnectivityError:error];
                    [self cancelImmediatelyWithError:error];
                }
                else
                {
                    if ([response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse *)response).statusCode != 200)
                    {
                        // The url for markers.geojson/features.json didn't work (some maps don't have any markers). Notify the delegate of the
                        // problem, and stop attempting to add marker icons, but don't bail out on whole the offline map download.
                        // The delegate can decide for itself whether it wants to continue or cancel.
                        //
                        [self notifyDelegateOfHTTPStatusError:((NSHTTPURLResponse *)response).statusCode url:response.URL];
                    }
                    else
                    {
                        // The marker geojson was successfully retrieved, so parse it for marker icons. Note that we shouldn't
                        // try to save it here, because it may already be in the download queue and saving it twice will mess
                        // up the count of urls to be downloaded!
                        //
                        NSArray *markerIconURLStrings = [self parseMarkerIconURLStringsFromGeojsonData:(NSData *)data];
                        if(markerIconURLStrings)
                        {
                            [urls addObjectsFromArray:markerIconURLStrings];
                        }
                    }


                    // ==========================================================================================================
                    // == WARNING! WARNING! WARNING!                                                                           ==
                    // == This stuff is a duplicate of the code immediately below it, but this copy is inside of a completion  ==
                    // == block while the other isn't. You will be sad and confused if you try to eliminate the "duplication". ==
                    //===========================================================================================================

                    // Create the database and start the download
                    //
                    NSError *error;
                    [self sqliteCreateDatabaseUsingMetadata:metadataDictionary urlArray:urls withError:&error];
                    if(error)
                    {
                        [self cancelImmediatelyWithError:error];
                    }
                    else
                    {
                        [self notifyDelegateOfInitialCount];
                        [self startDownloading];
                    }
                }
            }];
            [task resume];
        }
        else
        {
            // There aren't any marker icons to worry about, so just create database and start downloading
            //
            NSError *error;
            [self sqliteCreateDatabaseUsingMetadata:metadataDictionary urlArray:urls withError:&error];
            if(error)
            {
                [self cancelImmediatelyWithError:error];
            }
            else
            {
                [self notifyDelegateOfInitialCount];
                [self startDownloading];
            }
        }
    }];
}


- (NSArray *)parseMarkerIconURLStringsFromGeojsonData:(NSData *)data
{
    id markers;
    id value;
    NSMutableArray *iconURLStrings = [[NSMutableArray alloc] init];
    NSError *error;
    NSDictionary *simplestyleJSONDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if(!error)
    {
        // Find point features in the markers dictionary (if there are any) and add them to the map.
        //
        markers = simplestyleJSONDictionary[@"features"];

        if (markers && [markers isKindOfClass:[NSArray class]])
        {
            for (value in (NSArray *)markers)
            {
                if ([value isKindOfClass:[NSDictionary class]])
                {
                    NSDictionary *feature = (NSDictionary *)value;
                    NSString *type = feature[@"geometry"][@"type"];

                    if ([@"Point" isEqualToString:type])
                    {
                        NSString *size        = feature[@"properties"][@"marker-size"];
                        NSString *color       = feature[@"properties"][@"marker-color"];
                        NSString *symbol      = feature[@"properties"][@"marker-symbol"];
                        if (size && color && symbol)
                        {
                            NSURL *markerURL = [MBXRasterTileOverlay markerIconURLForSize:size symbol:symbol color:color];
                            if(markerURL && iconURLStrings )
                            {
                                [iconURLStrings addObject:[markerURL absoluteString]];
                            }
                        }
                    }
                }
                // This is the last line of the loop
            }
        }
    }

    // Return only the unique icon urls
    //
    NSSet *uniqueIcons = [NSSet setWithArray:iconURLStrings];
    return [uniqueIcons allObjects];
}


- (void)cancelImmediatelyWithError:(NSError *)error
{
    // Creating the database failed for some reason, so clean up and change the state back to available
    //
    _state = MBXOfflineMapDownloaderStateCanceling;
    [self notifyDelegateOfStateChange];

    if([_delegate respondsToSelector:@selector(offlineMapDownloader:didCompleteOfflineMapDatabase:withError:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate offlineMapDownloader:self didCompleteOfflineMapDatabase:nil withError:error];
        });
    }

    [_dataSession invalidateAndCancel];
    [_sqliteQueue cancelAllOperations];

    [_sqliteQueue addOperationWithBlock:^{
        [self setUpNewDataSession];
        _totalFilesWritten = 0;
        _totalFilesExpectedToWrite = 0;

        [[NSFileManager defaultManager] removeItemAtPath:_partialDatabasePath error:nil];

        _state = MBXOfflineMapDownloaderStateAvailable;
        [self notifyDelegateOfStateChange];
    }];
}


#pragma mark - API: Control an in-progress offline map download

- (void)cancel
{
    if(_state != MBXOfflineMapDownloaderStateCanceling && _state != MBXOfflineMapDownloaderStateAvailable)
    {
        // Stop a download job and discard the associated files
        //
        [_backgroundWorkQueue addOperationWithBlock:^{
            _state = MBXOfflineMapDownloaderStateCanceling;
            [self notifyDelegateOfStateChange];

            [_dataSession invalidateAndCancel];
            [_sqliteQueue cancelAllOperations];

            [_sqliteQueue addOperationWithBlock:^{
                [self setUpNewDataSession];
                _totalFilesWritten = 0;
                _totalFilesExpectedToWrite = 0;
                [[NSFileManager defaultManager] removeItemAtPath:_partialDatabasePath error:nil];

                if([_delegate respondsToSelector:@selector(offlineMapDownloader:didCompleteOfflineMapDatabase:withError:)])
                {
                    NSError *canceled = [NSError mbx_errorWithCode:MBXMapKitErrorCodeDownloadingCanceled reason:@"The download job was canceled" description:@"Download canceled"];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [_delegate offlineMapDownloader:self didCompleteOfflineMapDatabase:nil withError:canceled];
                    });
                }

                _state = MBXOfflineMapDownloaderStateAvailable;
                [self notifyDelegateOfStateChange];
            }];

        }];
    }
}


- (void)resume
{
    assert(_state == MBXOfflineMapDownloaderStateSuspended);

    // Resume a previously suspended download job
    //
    [_backgroundWorkQueue addOperationWithBlock:^{
        _state = MBXOfflineMapDownloaderStateRunning;
        [self startDownloading];
        [self notifyDelegateOfStateChange];
    }];
}


- (void)suspend
{
    if(_state == MBXOfflineMapDownloaderStateRunning)
    {
        // Stop a download job, preserving the necessary state to resume later
        //
        [_backgroundWorkQueue addOperationWithBlock:^{
            [_sqliteQueue cancelAllOperations];
            _state = MBXOfflineMapDownloaderStateSuspended;
            _activeDataSessionTasks = 0;
            [self notifyDelegateOfStateChange];
        }];
    }
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
    assert([offlineMapDatabase.path hasPrefix:[_offlineMapDirectory path]]);

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

- (void)removeOfflineMapDatabaseWithID:(NSString *)uniqueID
{
    for (MBXOfflineMapDatabase *database in [self offlineMapDatabases])
    {
        if ([database.uniqueID isEqualToString:uniqueID])
        {
            [self removeOfflineMapDatabase:database];
            return;
        }
    }
}

@end
