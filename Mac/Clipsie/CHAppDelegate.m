//
//  CHAppDelegate.m
//  Clipsie
//
//  Created by Sidney San Martín on 5/3/14.
//  Copyright (c) 2014 Coordinated Hackers. All rights reserved.
//

#import "CHAppDelegate.h"
#import "CHClipsieMacAdditions.h"
#import "NSString+CHAdditions.h"

@interface CHClipsieOfferAndNotification : NSObject

@property (retain) CHClipsieOffer *offer;
@property (retain) NSUserNotification *notification;

@end

@implementation CHClipsieOfferAndNotification

@end

@implementation CHAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:24];
	[self.statusItem setMenu:self.statusMenu];
	[self.statusItem setHighlightMode:YES];
    [self.statusItem setImage:[NSImage imageNamed:@"status-menu"]];
    [self.statusItem setAlternateImage:[NSImage imageNamed:@"status-menu-inverted"]];
    
    NSManagedObjectModel *managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"Clipsie" withExtension:@"momd"]];
    NSPersistentStoreCoordinator *persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:managedObjectModel];
    NSError *err;
    
    NSURL *applicationSupportDirectory = [[[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] firstObject] URLByAppendingPathComponent:@"Clipsie"];
    [[NSFileManager defaultManager] createDirectoryAtURL:applicationSupportDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    
    [persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                             configuration:nil
                                                       URL:[applicationSupportDirectory URLByAppendingPathComponent:@"Clipsie.sqlite"]
                                                   options:nil
                                                     error:&err];
    if (err != nil) {
        NSLog(@"%@", err);
    }
    
    self.managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    self.managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator;
    
    [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextWillSaveNotification
                                                      object:self.managedObjectContext
                                                       queue:nil
                                                  usingBlock:^(NSNotification *note) {
                                                      NSFetchRequest *fetchRequest = [self.managedObjectContext fetchRequestTemplateForName:@"AllOffers"];
                                                  }];
    
    [self.inboxArrayController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:nil];
    
    self.inboxMenuItems = [NSMutableArray new];
    
    self.listener.delegate = self;
    [self.listener start];
    
    self.browser.delegate = self;
    [self.browser start];
    
    self.menuItemsByDestination = [NSMutableDictionary new];
    self.destinationsByMenuItem = [NSMutableDictionary new];
    self.pendingOffers = [NSMutableArray new];
    self.pendingOffersByHash = [NSMutableDictionary new];
    
    NSUserNotificationCenter *nc = [NSUserNotificationCenter defaultUserNotificationCenter];
    nc.delegate = self;
    [nc removeAllDeliveredNotifications];
}

- (BOOL)isInboxEmpty
{
    return ((NSArray *)self.inboxArrayController.arrangedObjects).count == 0;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [self willChangeValueForKey:@"isInboxEmpty"];
    [self didChangeValueForKey:@"isInboxEmpty"];
    
    NSLog(@"Change object: %@", change);
    for (NSMenuItem *menuItem in self.inboxMenuItems) {
        [self.statusMenu removeItem:menuItem];
    }
    [self.inboxMenuItems removeAllObjects];
    
    for (CHClipsieOffer *offer in self.inboxArrayController.arrangedObjects) {
        NSMenuItem *offerMenuItem = [NSMenuItem new];
        offerMenuItem.representedObject = offer;
        offerMenuItem.title = [offer.preview truncate:20 overflow:@"…"];
        offerMenuItem.target = self;
        offerMenuItem.action = @selector(offerMenuItemClicked:);
        [self.inboxMenuItems addObject:offerMenuItem];
        [self.statusMenu insertItem:offerMenuItem atIndex:[self.statusMenu indexOfItem:self.inboxTitleMenuItem] + 1];
    }
}

- (void)gotOffer:(CHClipsieOffer *)offer
{
    NSUserNotification *notification = [NSUserNotification new];
    
    CHClipsieOfferAndNotification *offerAndNotification = [CHClipsieOfferAndNotification new];
    offerAndNotification.offer = offer;
    offerAndNotification.notification = notification;
    
    if ([self.pendingOffers count] >= 5) {
        CHClipsieOfferAndNotification *offerToDestroy = [self.pendingOffers objectAtIndex:0];
        [self.pendingOffers removeObjectAtIndex:0];
        [self.pendingOffersByHash removeObjectForKey:offerToDestroy];
        [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification:offerToDestroy.notification];
    }
    
    NSNumber *key = [NSNumber numberWithUnsignedInteger:[offer hash]];
    
    [self.pendingOffers addObject:offerAndNotification];
    [self.pendingOffersByHash setObject:offerAndNotification forKey:key];

    notification.title = @"Incoming clipboard!";
    notification.informativeText = [NSString stringWithFormat:@"Click to copy “%@”", [offer.preview truncate:20 overflow:@"…"]];
    notification.hasActionButton = YES;
    notification.actionButtonTitle = @"Accept";
    notification.otherButtonTitle = @"Ignore";
    notification.userInfo = @{@"key": key};
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

- (void)foundDestination:(CHClipsieDestination *)destination moreComing:(BOOL)moreComing
{
    NSMenuItem *menuItem = [NSMenuItem new];
    
    // Hax hax hax
    [self.menuItemsByDestination setObject:menuItem forKey:[NSValue valueWithPointer:(__bridge void *)(destination)]];
    [self.destinationsByMenuItem setObject:destination forKey:[NSValue valueWithPointer:(__bridge void *)(menuItem)]];
    
    [menuItem setTitle:destination.name];
    menuItem.target = self;
    menuItem.action = @selector(sendMenuItemClicked:);
    [self.statusMenu insertItem:menuItem atIndex:0];
}

- (void)lostDestination:(CHClipsieDestination *)destination moreComing:(BOOL)moreComing
{
    NSValue *key = [NSValue valueWithPointer:(__bridge void *)(destination)];
    NSMenuItem *menuItem = [self.menuItemsByDestination objectForKey:key];
    [self.menuItemsByDestination removeObjectForKey:key];
    [self.destinationsByMenuItem removeObjectForKey:[NSValue valueWithPointer:(__bridge const void *)(menuItem)]];
    
    [self.statusMenu removeItem:menuItem];
}

- (void)offerMenuItemClicked:(NSMenuItem*)menuItem
{
    [((CHClipsieOffer *)menuItem.representedObject) accept];
}

- (void)sendMenuItemClicked:(NSMenuItem*)menuItem
{
    CHClipsieDestination *destination = [self.destinationsByMenuItem objectForKey:[NSValue valueWithPointer:(__bridge const void *)(menuItem)]];

    NSManagedObjectContext *managedObjectContext = [NSManagedObjectContext new];
    managedObjectContext.parentContext = self.managedObjectContext;
    [destination sendOffer:[CHClipsieOffer offerWithClipboardWithManagedObjectContext:managedObjectContext]];
    
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification
{
    return YES;
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification
{
    NSNumber *key = [notification.userInfo objectForKey:@"key"];
    CHClipsieOfferAndNotification *offerAndNotification = [self.pendingOffersByHash objectForKey:key];
    [offerAndNotification.offer accept];
}

- (NSManagedObjectContext *)managedObjectContextForOffer {
    return self.managedObjectContext;
}

@end