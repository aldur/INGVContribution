//
//  AppDelegate.m

//
//  Created by Matt Galloway on 29/02/2012.
//  Copyright (c) 2012 Swipe Stack Ltd. All rights reserved.
//

#import "AppDelegate.h"
#import "coCheckmarkQuestionTVC.h"
#import "coStartingViewController.h"
#import "MainTabBarController.h"
#import <CoreLocation/CoreLocation.h>

#import "Server.h"

@interface AppDelegate () <CLLocationManagerDelegate, UIAlertViewDelegate>
@property (strong, nonatomic) CLLocationManager* backgroundLocationManager;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;

@end

@implementation AppDelegate

@synthesize window = _window;

# pragma mark - background location manager 
- (CLLocationManager *) backgroundLocationManager {
    if (!_backgroundLocationManager) {
        _backgroundLocationManager = [[CLLocationManager alloc] init];
        _backgroundLocationManager.delegate = self;
    }
    return _backgroundLocationManager;
}

# pragma mark - CLLocationManagerDelegate Methods
- (void) locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    
    // Handle location updates as normal
    CLLocation *location = [locations lastObject];
//    NSLog(@"%f, %f", coordinate.latitude, coordinate.longitude);
    [self sendBackgroundLocationToServer:location];
    
//    UILocalNotification *localNotification = [[UILocalNotification alloc] init];
//    
////    Debugging purposes
//    localNotification.alertBody = [NSString stringWithFormat:@"Nuova posizione: %f, %f", location.coordinate.latitude, location.coordinate.longitude];
//    localNotification.hasAction = NO;
    
//    [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
//    
//    [manager stopMonitoringSignificantLocationChanges];
//    [manager performSelector:@selector(startMonitoringSignificantLocationChanges) withObject:nil afterDelay:50*60];
}

- (void) locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
//    What else could we do? We're in background!
    NSLog(@"Background location manager error: %@", error);
}

- (void) sendBackgroundLocationToServer: (CLLocation *) location
{
    // REMEMBER. We are running in the background if this is being executed.
    // We can't assume normal network access.
    // bgTask is defined as an instance variable of type UIBackgroundTaskIdentifier
 
    // Note that the expiration handler block simply ends the task. It is important that we always
    // end tasks that we have started.
    
    self.backgroundTaskIdentifier = [[UIApplication sharedApplication]
              beginBackgroundTaskWithExpirationHandler:
              ^{
                  [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
                }];
    
    CLLocationCoordinate2D coordinate = location.coordinate;
    NSString *postString = [[NSString alloc] initWithFormat:@"lat=%f&lng=%f&devid=%@",
                      coordinate.latitude,
                      coordinate.longitude,
                      [AppDelegate getApplicationUUID]];
    
    NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/%@", SERVER, LOCALIZATION]];
    NSMutableURLRequest *rqst = [NSMutableURLRequest requestWithURL:url];
    rqst.HTTPBody = [postString dataUsingEncoding:NSUTF8StringEncoding];
    rqst.HTTPMethod = @"POST";
    NSURLSessionDataTask *postDataTask = [session dataTaskWithRequest:rqst completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error == nil) {
//            NSString * text = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
//            NSLog(@"Data = %@",text);
            [session invalidateAndCancel];
        } else {
            NSLog(@"%@", error);
        }
    }];
    
    [postDataTask resume];

    if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
         self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    }
}

# pragma mark - Application life cycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:
     (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeNone | UIRemoteNotificationTypeNewsstandContentAvailability)];
    
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
//        Al primo avvio, chiediamo all'utente i permessi giusti.
        [self.backgroundLocationManager startMonitoringSignificantLocationChanges];
    }
    
//    Notifiche locali
    UILocalNotification *localNotification = [launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
    if (localNotification) {
        [self handleLongQuestionarioNotification:localNotification.userInfo];
    }
    
//    Notifiche push
    NSDictionary *remoteNotification = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    if (remoteNotification) {
        [self handleQuestionarioPushNotification:[remoteNotification objectForKey:TERREMOTO_ID]];
    }
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorized) {
        if ([CLLocationManager locationServicesEnabled]) {
            if (application.backgroundRefreshStatus == UIBackgroundRefreshStatusAvailable) {
                [self.backgroundLocationManager startMonitoringSignificantLocationChanges];
            }
        }
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    [self.backgroundLocationManager stopMonitoringSignificantLocationChanges];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    [[UIApplication sharedApplication] unregisterForRemoteNotifications];
}

# pragma mark - Handle local notifications

- (void) application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    if ([application applicationState] == UIApplicationStateInactive) {
        [self handleLongQuestionarioNotification:[notification.userInfo copy]];
        [[UIApplication sharedApplication] cancelLocalNotification:notification];
    }
}

- (void) handleLongQuestionarioNotification:(NSDictionary *)questionarioDictionary {
/*    TODO: Questo metodo si occupa di aprire la pagina dei dettagli del terremoto per cui compilare il questionario completo.
    Probabilmente andrà modificato in base allo storyboard utilizzato dal gruppo "Information"
    Quello che dev'essere fatto, in pratica, è caricare la tabbar, settare la sezione a quella di informatione poi aprire
    i dettagli del terremoto in oggetto, avendo cura di permettere all'utente di tornare indietro, quindi implementando a dovere
    lo stack della navigation bar.
*/
    
//    Gli storyboard
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"mainStoryboard" bundle:nil];
    UIStoryboard *coStoryboard = [UIStoryboard storyboardWithName:@"coStoryboard" bundle:nil];
    
//    Tab bar principale
    MainTabBarController *mainTabBar = [mainStoryboard instantiateInitialViewController];
    mainTabBar.selectedIndex = 0;
    
//    Navigation controller di Information
    UINavigationController *informationNavigationController = mainTabBar.viewControllers[0];
    coStartingViewController *startingViewController = (coStartingViewController *)informationNavigationController.topViewController;
    
//    Segue ai dettagli del terremoto
    [startingViewController performSegueWithIdentifier:@"coTerremotoDetailSegue" sender:startingViewController];
    
// Da qui in poi non dovrebbe esservi bisogno di modificare nulla!
    coQuestionario *questionario = [coQuestionario dictionaryToQuestionario:questionarioDictionary];
    
    coCheckmarkQuestionTVC *firstQuestion = [coStoryboard instantiateViewControllerWithIdentifier:@"coFirstLongQuestion"];
    
    firstQuestion.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Annulla" style:UIBarButtonSystemItemUndo target:firstQuestion action:@selector(cancelButtonPressed:)];
    
    UINavigationController *questionNavigationController = [[UINavigationController alloc] initWithRootViewController:firstQuestion];
    
    firstQuestion.delegate = startingViewController;
    firstQuestion.delegate.questionario = questionario;
    firstQuestion.resume = YES;
    
    self.window.rootViewController = mainTabBar;
    
    double delayInSeconds = 0.1;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [startingViewController presentViewController:questionNavigationController animated:NO completion:nil];
    });
    
    [self.window makeKeyAndVisible];
}

# pragma mark - Generate app UUID

#define UUID_KEY @"uuid_key"
+ (NSString *) getApplicationUUID {
//    Generiamo una volta per tutte l'uuid.
    NSString *uuid = [[NSUserDefaults standardUserDefaults] objectForKey:UUID_KEY];
    
    if (!uuid) {
        uuid = [[NSUUID UUID] UUIDString];
        [[NSUserDefaults standardUserDefaults] setObject:uuid forKey:UUID_KEY];
        
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    return uuid;
}

# pragma mark - Handle remote notification
- (void) application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    NSLog(@"Notifica remota ricevuta!");
    
#if !TARGET_IPHONE_SIMULATOR
    
    if ([application applicationState] == UIApplicationStateInactive) {
        [self handleQuestionarioPushNotification:[userInfo objectForKey:TERREMOTO_ID]];
    } else if ([application applicationState] == UIApplicationStateActive) {
        NSString *message = nil;
        
        NSDictionary *aps = [userInfo objectForKey:@"aps"];
        id alert = [aps objectForKey:@"alert"];
        
        if ([alert isKindOfClass:[NSString class]]) {
            message = alert;
        } else if ([alert isKindOfClass:[NSDictionary class]]) {
            message = [alert objectForKey:@"body"];
        }
        
//        TODO: Cambiare i testi in base al corpo della notifica push scelta da chi di dovere.
        if (message) {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"%@", message]
                                                                message:@"Vuoi compilare il questionario?"  delegate:self
                                                      cancelButtonTitle:@"No"
                                                      otherButtonTitles:@"Si", nil];
            [alertView show];
            alertView.tag = [[userInfo objectForKey:TERREMOTO_ID] integerValue];
        }
    }
    
#endif
    
}

- (void) handleQuestionarioPushNotification: (NSNumber *)terremotoID {
    /*    TODO: Questo metodo si occupa di aprire la pagina dei dettagli del terremoto per cui compilare il questionario completo.
     Probabilmente andrà modificato in base allo storyboard utilizzato dal gruppo "Information"
     Quello che dev'essere fatto, in pratica, è caricare la tabbar, settare la sezione a quella di informatione poi aprire
     i dettagli del terremoto in oggetto, avendo cura di permettere all'utente di tornare indietro, quindi implementando a dovere
     lo stack della navigation bar.
     */
    
    //    Gli storyboard
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"mainStoryboard" bundle:nil];
    
    //    Tab bar principale
    MainTabBarController *mainTabBar = [mainStoryboard instantiateInitialViewController];
    mainTabBar.selectedIndex = 0;
    
    self.window.rootViewController = mainTabBar;
    
    //    Navigation controller di Information
    UINavigationController *informationNavigationController = mainTabBar.viewControllers[0];
    coStartingViewController *startingViewController = (coStartingViewController *)informationNavigationController.topViewController;
    
    //    Inseriamo l'id del terremoto da visualizzare:
    startingViewController.terremotoID = terremotoID;
    
    //    Segue ai dettagli del terremoto
    [startingViewController performSegueWithIdentifier:@"coTerremotoDetailSegue" sender:startingViewController];
    
    //    Schermata di dettagli terremoto
    coStartingViewController *exampleTerremotoDetailVC = (coStartingViewController *)informationNavigationController.visibleViewController;
    
    double delayInSeconds = 0.1;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [exampleTerremotoDetailVC performSegueWithIdentifier:@"coQuestionarioTerremotoSegueNoAnimation" sender:exampleTerremotoDetailVC];
    });
    
    // Da qui in poi non dovrebbe esservi bisogno di modificare nulla!
    [self.window makeKeyAndVisible];
}

# pragma mark - Remote notifications tokens
/**
 * iOS: Fetch and Format Device Token and Register Important Information to Remote Server
 */
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)devToken {
    
//    NSLog(@"Device token: %@", devToken);
    
#if !TARGET_IPHONE_SIMULATOR
    
    // Get Bundle Info for Remote Registration (handy if you have more than one app)
    NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    
    // Check what Notifications the user has turned on.  We registered for all three, but they may have manually disabled some or all of them.
    // Set the defaults to disabled unless we find otherwise...
    NSString *pushBadge = @"disabled";
    NSString *pushAlert = @"disabled";
    NSString *pushSound = @"disabled";
    
    UIRemoteNotificationType enabledTypes = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];
    if (enabledTypes & UIRemoteNotificationTypeBadge) {
        pushBadge = @"enabled";
    }

    if (enabledTypes & UIRemoteNotificationTypeSound) {
        pushSound = @"enabled";
    }
    
    if (enabledTypes & UIRemoteNotificationTypeAlert) {
        pushAlert = @"enabled";
    }
    
    // Get the users Device Model, Display Name, Unique ID (, Token & Version Number
    UIDevice *dev = [UIDevice currentDevice];
    NSString *deviceUuid = [AppDelegate getApplicationUUID];
    NSString *deviceName = dev.name;
    NSString *deviceModel = dev.model;
    NSString *deviceSystemVersion = [dev.systemVersion stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    
    // Prepare the Device Token for Registration (remove spaces and < >)
    NSString *deviceToken = [[[[devToken description]
                                stringByReplacingOccurrencesOfString:@"<" withString:@""]
                                stringByReplacingOccurrencesOfString:@">" withString:@""]
                                stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    // Build URL String for Registration
    NSString *urlString = [[[NSString alloc] init] stringByAppendingString:@"appversion="];
    urlString = [urlString stringByAppendingString:appVersion];
    urlString = [urlString stringByAppendingString:@"&deviceuid="];
    urlString = [urlString stringByAppendingString:deviceUuid];
    urlString = [urlString stringByAppendingString:@"&devicetoken="];
    urlString = [urlString stringByAppendingString:deviceToken];
    urlString = [urlString stringByAppendingString:@"&devicename="];
    urlString = [urlString stringByAppendingString:deviceName];
    urlString = [urlString stringByAppendingString:@"&devicemodel="];
    urlString = [urlString stringByAppendingString:deviceModel];
    urlString = [urlString stringByAppendingString:@"&deviceversion="];
    urlString = [urlString stringByAppendingString:deviceSystemVersion];
    urlString = [urlString stringByAppendingString:@"&pushbadge="];
    urlString = [urlString stringByAppendingString:pushBadge];
    urlString = [urlString stringByAppendingString:@"&pushalert="];
    urlString = [urlString stringByAppendingString:pushAlert];
    urlString = [urlString stringByAppendingString:@"&pushsound="];
    urlString = [urlString stringByAppendingString:pushSound];
    
    NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/%@", SERVER, PUSH]];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPBody = [urlString dataUsingEncoding:NSUTF8StringEncoding];
    request.HTTPMethod = @"POST";
    
    NSURLSessionDataTask *postDataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!error) {
//            NSString *text = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
//            NSLog(@"Data = %@", text);
            [session invalidateAndCancel];
        } else {
            NSLog(@"%@", error);
        }
    }];
    
    [postDataTask resume];

#endif
    
}

- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error
{
	NSLog(@"Failed to get token, error: %@", error);
}

# pragma mark - UIAlertViewDelegate methods
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    [self handleQuestionarioPushNotification:[NSNumber numberWithInt:alertView.tag]];
}

@end
