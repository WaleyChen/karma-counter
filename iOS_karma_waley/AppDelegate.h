//
//  AppDelegate.h
//  iOS_karma_waley
//
//  Created by Waley Chen on 2014-04-30.
//
//

#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (readonly, strong, nonatomic) NSManagedObjectContext          *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel            *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator    *persistentStoreCoordinator;

@property (strong, nonatomic) UIWindow *window;

- (NSURL *)applicationDocumentsDirectory;
- (void)saveContext;
+ (NSManagedObjectContext*)sharedManagedObjectContext;

@end
