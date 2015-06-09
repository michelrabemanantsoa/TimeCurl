/*
 
 Copyright (C) 2013-2015, Patrick Jayet
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 
*/

#import "CoreDataWrapper.h"
#import "AppDelegate.h"
#import <CoreData/CoreData.h>
#import "TimeUtils.h"

NSString * const DPModelName        = @"TimeWarp";
NSString * const DPStoreName        = @"TimeCurl.sqlite";
NSString * const DPUbiquitousName   = @"com~timecurl~coredataicloud";
NSString * const iCloudStoreMigrated = @"store.migrated";


@interface CoreDataWrapper ()

@end


@implementation CoreDataWrapper

+ (instancetype)shared
{
    static CoreDataWrapper *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        if (sharedInstance == nil){
            sharedInstance = [[CoreDataWrapper alloc] init];
        }
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        // initialization
    }
    return self;
}

#pragma mark needed for CoreData

- (NSManagedObjectContext*) managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    NSPersistentStoreCoordinator* coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
        _managedObjectContext.mergePolicy = [[NSMergePolicy alloc] initWithMergeType:NSMergeByPropertyObjectTrumpMergePolicyType];
    }
    return _managedObjectContext;
}

- (NSManagedObjectModel*) managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    
    // new
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:DPModelName withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    
    // old
    //_managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
    
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator*) persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [self storeUrl];
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];

    // not using the icloud options anymore
    NSDictionary *options = [self localOptions];
    
    NSPersistentStore *store = [_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                             configuration:nil
                                                                       URL:storeURL
                                                                   options:options
                                                                     error:&error];
    if (!store) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    // no migration to do
    //if (![self isStoreMigrated]) {
    //    [self migrateiCloudStoreToLocalStore];
    //}
    
    return _persistentStoreCoordinator;
}

- (BOOL)isStoreMigrated
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:iCloudStoreMigrated];
}

- (NSURL*)storeUrl
{
    return [[self applicationDocumentsDirectory] URLByAppendingPathComponent:DPStoreName];
}

- (void)migrateiCloudStoreToLocalStore
{
    NSLog(@"Migrating store from iCloud to local");
    NSPersistentStore* store = [self.persistentStoreCoordinator persistentStores].firstObject;
    
    NSDictionary *options = @{ NSMigratePersistentStoresAutomaticallyOption : @YES,
                               NSInferMappingModelAutomaticallyOption : @YES,
                               NSPersistentStoreRemoveUbiquitousMetadataOption : @YES
                               };

    NSError *error = nil;
    NSPersistentStore *newStore = [self.persistentStoreCoordinator migratePersistentStore:store toURL:[self storeUrl] options:options withType:NSSQLiteStoreType error:&error];
    
    if (error) {
        NSLog(@"Error happened while migrating store from iCloud to local: %@", error);
    }
    else {
        [self reloadStore:newStore withOptions:options];
    }
}

- (NSDictionary*)localOptions
{
    return @{ NSMigratePersistentStoresAutomaticallyOption : @YES,
              NSInferMappingModelAutomaticallyOption : @YES,
              NSPersistentStoreRemoveUbiquitousMetadataOption : @YES
            };
}

- (NSDictionary*)icloudOptions
{
    return @{ NSMigratePersistentStoresAutomaticallyOption : @YES,
              NSInferMappingModelAutomaticallyOption : @YES,
              NSPersistentStoreUbiquitousContentNameKey : DPUbiquitousName
            };
}

- (void)reloadStore:(NSPersistentStore *)store withOptions:(NSDictionary*)options
{
    if (store) {
        [self.persistentStoreCoordinator removePersistentStore:store error:nil];
    }
    
    [self.persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                               configuration:nil
                                         URL:[self storeUrl]
                                     options:options
                                       error:nil];
    
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:iCloudStoreMigrated];
}

- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

# pragma iCloud Support

- (void)registerUbiquitousCallbacks
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(persistentStoreDidImportUbiquitiousContentChanges:)
                                                 name:NSPersistentStoreDidImportUbiquitousContentChangesNotification
                                               object:_persistentStoreCoordinator];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(storesWillChange:)
                                                 name:NSPersistentStoreCoordinatorStoresWillChangeNotification
                                               object:_persistentStoreCoordinator];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(storesDidChange:)
                                                 name:NSPersistentStoreCoordinatorStoresDidChangeNotification
                                               object:_persistentStoreCoordinator];
}

- (void)persistentStoreDidImportUbiquitiousContentChanges:(NSNotification *)changeNotification
{
    NSLog(@">>>> MERGE CANDIDATE");

    NSManagedObjectContext *moc = [self managedObjectContext];
    [moc performBlock:^{
        NSDictionary *userInfo = [changeNotification userInfo];
        NSLog(@">>>> BEGIN");
        NSLog(@"%@", userInfo);
        NSLog(@">>>> END");
        if (([userInfo objectForKey:NSInsertedObjectsKey] > 0) &&
            ([userInfo objectForKey:NSUpdatedObjectsKey] > 0) &&
            ([userInfo objectForKey:NSDeletedObjectsKey] > 0))
        {
            NSLog(@">>>> MERGE");
            [moc mergeChangesFromContextDidSaveNotification:changeNotification];
            [self.storeChangeDelegate storeDidChange];
        }
    }];
}

- (void)storesWillChange:(NSNotification *)n
{
    NSManagedObjectContext *moc = [self managedObjectContext];
    [moc performBlockAndWait:^{
        NSError *error = nil;
        if ([moc hasChanges]) {
            [moc save:&error];
        }
        [moc reset];
    }];
    //reset user interface
    
    NSLog(@">>>> Stores Will Change, TODO update UI");
    NSLog(@">>>> BEGIN");
    NSDictionary *userInfo = [n userInfo];
    NSLog(@"%@", userInfo);
    NSLog(@">>>> END");

}

- (void)storesDidChange:(NSNotification *)n
{
    NSLog(@">>>> BEGIN");
    NSDictionary *userInfo = [n userInfo];
    NSLog(@"%@", userInfo);
    [self.storeChangeDelegate storeDidChange];
    NSLog(@">>>> END");

}

#pragma mark utility methods

- (NSArray*) fetchAllProjects
{
    NSManagedObjectContext* managedObjectContext = [self managedObjectContext];
    NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription* entity = [NSEntityDescription entityForName:@"Project" inManagedObjectContext:managedObjectContext];
    [fetchRequest setEntity:entity];
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"sortOrder" ascending:YES];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    NSError* error = nil;
    NSArray* result = [managedObjectContext executeFetchRequest:fetchRequest error:&error];

    if ([self logError:error withMessage:@"fetch all projects"]) {
        return nil;
    }
    else {
        if ([self anyProjectWithoutSortOrder:result]) {
            [self setProjectSortOrder:result];
        }
        return result;
    }
}

- (void) setProjectSortOrder:(NSArray*)projects
{
    NSInteger idx = 0;
    for (Project* project in projects) {
        project.sortOrder = [NSNumber numberWithInteger:idx];
        idx++;
    }

    [self saveContext];
}

- (BOOL)anyProjectWithoutSortOrder:(NSArray*)projects
{
    NSUInteger idx = [projects indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL* stop){
        return ((Project*)obj).sortOrder == nil;
    }];
    return idx != NSNotFound;
}

- (NSArray*) fetchAllActivities
{
    NSLog(@"Fetch all activities");
    
    NSManagedObjectContext* managedObjectContext = [self managedObjectContext];
    NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription* entity = [NSEntityDescription entityForName:@"Activity" inManagedObjectContext:managedObjectContext];
    [fetchRequest setEntity:entity];
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    [fetchRequest setSortDescriptors:sortDescriptors];

    NSError* error = nil;
    NSArray* result = [managedObjectContext executeFetchRequest:fetchRequest error:&error];

    if ([self logError:error withMessage:@"fetch all activities"]) {
        return nil;
    }
    else {
        return result;
    }
}

- (NSArray*) fetchActivitiesForDate:(NSDate*) date
{
    NSLog(@"Fetch activities for %@", date);
    
    NSManagedObjectContext* managedObjectContext = [self managedObjectContext];
    NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription* entity = [NSEntityDescription entityForName:@"Activity" inManagedObjectContext:managedObjectContext];
    [fetchRequest setEntity:entity];
    
    NSDate* day      = [TimeUtils dayForDate:date];
    NSDate* dayAfter = [day dateByAddingTimeInterval:3600*24];
    // TODO perhaps not the most efficient query
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"self.date >= %@ AND self.date < %@", day, dayAfter];
    [fetchRequest setPredicate:predicate];
    
    NSError* error = nil;
    NSArray* result = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    
    if ([self logError:error withMessage:@"fetch all activities"]) {
        return nil;
    }
    else {
        return result;
    }
}

- (NSArray*) fetchAllActivitiesByDay
{
    NSArray* allActivities = [self fetchAllActivities];
    return [self groupActivitiesByDay:allActivities];
}

- (NSArray*) fetchActivitiesByDayForMonth:(NSDate*) date
{
    NSArray* activities = [self fetchActivitiesForMonth:date];
    return [self groupActivitiesByDay:activities];
}

- (NSArray*) fetchActivitiesForMonth:(NSDate*) date
{
    //NSLog(@"Fetch activities for month %@", date);
    
    NSDate* month      = [TimeUtils monthForDate:date];
    NSDate* monthAfter = [TimeUtils incrementMonthForDate:month];
    return [self fetchActivitiesBetweenDate:month andExclusiveDate:monthAfter];
}

- (NSArray*) fetchActivitiesBetweenDate:(NSDate*)fromDate andExclusiveDate:(NSDate*)toDate
{
    NSLog(@"Fetch activities between %@ and %@ exclusive", fromDate, toDate);

    NSManagedObjectContext* managedObjectContext = [self managedObjectContext];
    NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription* entity = [NSEntityDescription entityForName:@"Activity" inManagedObjectContext:managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // TODO perhaps not the most efficient query
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"self.date >= %@ AND self.date < %@", fromDate, toDate];
    [fetchRequest setPredicate:predicate];
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    NSError* error = nil;
    NSArray* result = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    
    if ([self logError:error withMessage:@"fetch activities between"]) {
        return nil;
    }
    
    return result;
}

- (NSArray*) groupActivitiesByDay:(NSArray*)activities
{
    NSMutableArray* activitiesByDay = [NSMutableArray array];
    NSDate* currentDay = nil;
    NSMutableArray* activitiesForSingleDay = nil;
    for (Activity* activity in activities) {
        NSDate* actDay = [TimeUtils dayForDate:activity.date];
        
        if (![actDay isEqual:currentDay]) {
            activitiesForSingleDay = [NSMutableArray array];
            [activitiesByDay addObject:activitiesForSingleDay];
            currentDay = actDay;
        }
        
        [activitiesForSingleDay addObject:activity];
    }
    
    return activitiesByDay;
}

- (Project*) newProject
{
    NSManagedObjectContext* managedObjectContext = [self managedObjectContext];
    return [NSEntityDescription insertNewObjectForEntityForName:@"Project" inManagedObjectContext:managedObjectContext];
}

- (Activity*) newActivity
{
    NSManagedObjectContext* managedObjectContext = [self managedObjectContext];
    return [NSEntityDescription insertNewObjectForEntityForName:@"Activity" inManagedObjectContext:managedObjectContext];
}

- (TimeSlot*) newTimeSlot
{
    NSManagedObjectContext* managedObjectContext = [self managedObjectContext];
    return [NSEntityDescription insertNewObjectForEntityForName:@"TimeSlot" inManagedObjectContext:managedObjectContext];
}

#define TCMaxSaveAttempts 5

- (void) saveContext
{
    NSError* error = nil;
    if (![[self managedObjectContext] save:&error]) {
        NSLog(@"Error happened while saving context: %@", [error localizedDescription]);
        NSString *title = NSLocalizedString(@"A problem arose. Could not save changes.", @"Save fail");
        NSString *message = NSLocalizedString(@"You should quit as soon as possible, "
                                              @"because continuing could cause other problems.", @"");
        [self showAlertWithTitle:title andMessage:message];
    }
}

- (void)showAlertWithTitle:(NSString*)title andMessage:(NSString*)message
{
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
    [alert show];
}


- (void) deleteObject:(id)obj
{
    NSManagedObjectContext* managedObjectContext = [self managedObjectContext];
    [managedObjectContext deleteObject:obj];
}

- (BOOL) logError:(NSError*)error withMessage:(NSString*)msg {
    if (error != nil) {
        NSLog(@"Error - %@: %@, %@", msg, [error localizedDescription], [error userInfo]);
        return YES;
    }
    else {
        return NO;
    }
}
@end
