//
//  MBXConstantsAndTypes.h
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

#ifndef MBXMapKit_MBXConstantsAndTypes_h
#define MBXMapKit_MBXConstantsAndTypes_h


#pragma mark - Constants for the MBXMapKit error domain

extern NSString *const MBXMapKitErrorDomain;
extern NSInteger const MBXMapKitErrorCodeHTTPStatus;
extern NSInteger const MBXMapKitErrorCodeDictionaryMissingKeys;
extern NSInteger const MBXMapKitErrorCodeDownloadingCanceled;
extern NSInteger const MBXMapKitErrorCodeOfflineMapHasNoDataForURL;
extern NSInteger const MBXMapKitErrorCodeOfflineMapSqlite;
extern NSInteger const MBXMapKitErrorCodeURLSessionConnectivity;


#pragma mark - Image quality constants

typedef NS_ENUM(NSUInteger, MBXRasterImageQuality) {
    MBXRasterImageQualityFull = 0,   // default
    MBXRasterImageQualityPNG32 = 1,  // 32 color indexed PNG
    MBXRasterImageQualityPNG64 = 2,  // 64 color indexed PNG
    MBXRasterImageQualityPNG128 = 3, // 128 color indexed PNG
    MBXRasterImageQualityPNG256 = 4, // 256 color indexed PNG
    MBXRasterImageQualityJPEG70 = 5, // 70% quality JPEG
    MBXRasterImageQualityJPEG80 = 6, // 80% quality JPEG
    MBXRasterImageQualityJPEG90 = 7  // 90% quality JPEG
};



#endif
