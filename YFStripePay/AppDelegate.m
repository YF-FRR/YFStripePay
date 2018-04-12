//
//  AppDelegate.m
//  YFStripePay
//
//  Created by ios_yangfei on 2018/4/8.
//  Copyright © 2018年 jianghu3. All rights reserved.
//

#import "AppDelegate.h"
#import <Stripe/Stripe.h>

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    
   

    self.window=[[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [self.window makeKeyAndVisible];
    
    self.window.backgroundColor=[UIColor whiteColor];
    self.window.rootViewController=[[UINavigationController alloc] initWithRootViewController:[[NSClassFromString(@"ViewController") alloc] init] ];
    
    return YES;
}

// This method handles opening native URLs (e.g., "yourexampleapp://")
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    BOOL stripeHandled = [Stripe handleStripeURLCallbackWithURL:url];
    if (stripeHandled) {
        return YES;
    } else {
        // This was not a stripe url – do whatever url handling your app
        // normally does, if any.
    }
    return NO;
}

// This method handles opening universal link URLs (e.g., "https://example.com/stripe_ios_callback")
- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray * _Nullable))restorationHandler {
    if (userActivity.activityType == NSUserActivityTypeBrowsingWeb) {
        if (userActivity.webpageURL) {
            BOOL stripeHandled = [Stripe handleStripeURLCallbackWithURL:userActivity.webpageURL];
            if (stripeHandled) {
                return YES;
            } else {
                // This was not a stripe url – do whatever url handling your app
                // normally does, if any.
            }
            return NO;
        }
    }
    return NO;
}


@end
