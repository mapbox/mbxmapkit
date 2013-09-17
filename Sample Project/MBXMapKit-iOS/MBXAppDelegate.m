//
//  MBXAppDelegate.m
//  MBXMapKit
//
//  Created by Justin R. Miller on 9/4/13.
//  Copyright (c) 2013 MapBox. All rights reserved.
//

#import "MBXAppDelegate.h"

#import "MBXViewController.h"

@implementation MBXAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[MBXViewController alloc] initWithNibName:nil bundle:nil];
    [self.window makeKeyAndVisible];

    return YES;
}

@end