//
//  OverviewControllerViewController.m
//  TimeWarp
//
//  Created by pat on 01.07.2013.
//  Copyright (c) 2013 zuehlke. All rights reserved.
//

#import "OverviewController.h"
#import "ModelUtils.h"
#import "TimeUtils.h"


@interface OverviewController ()
- (void) loadData;
- (void) initCurrentDate;
- (void) updateTitle;
@end

@implementation OverviewController


#pragma mark custom methods

- (void) loadData
{
    self.activitiesByDay = [NSMutableArray arrayWithArray:[ModelUtils fetchActivitiesByDayForMonth:self.currentDate]];
    
    [self.tableView reloadData];
}

- (void) initCurrentDate
{
    self.currentDate = [NSDate date];
}

- (void) updateTitle
{
    // total hours for that month
    double totTime = 0.0;
    for (NSArray* dayActivities in self.activitiesByDay) {
        for (Activity* activity in dayActivities) {
            totTime += [activity duration];
        }
    }
    
    // date
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MMM yyyy"];
    NSString* dateString = [dateFormatter stringFromDate:self.currentDate];
    
    // title
    self.title = [NSString stringWithFormat:@"%@ (%.2f)", dateString, totTime];
}

- (IBAction) sharePressed:(id)sender
{
    NSLog(@"TODO implement CSV share functionality");
}

- (IBAction)handleSwipeRight:(UISwipeGestureRecognizer *)sender
{
	if (sender.state == UIGestureRecognizerStateEnded) {
		NSLog(@"Current date minus one month");
        self.currentDate = [TimeUtils decrementMonthForMonth:self.currentDate];
        [self loadData];
        [self updateTitle];
    }
}

- (IBAction)handleSwipeLeft:(UISwipeGestureRecognizer *)sender
{
	if (sender.state == UIGestureRecognizerStateEnded) {
		NSLog(@"Current date plus one month");
        self.currentDate = [TimeUtils incrementMonthForMonth:self.currentDate];
        [self loadData];
        [self updateTitle];
    }
}

#pragma mark common methods from UIViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self initCurrentDate];
    
    _dateFormatter = [[NSDateFormatter alloc] init];
    [_dateFormatter setDateFormat:@"EEEE d"];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self loadData];
    [self updateTitle];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self.activitiesByDay count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // +1 is for the day title cell
    return [[self.activitiesByDay objectAtIndex:section] count] + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell* cell = nil;
    
    // case day title cell
    if (indexPath.row == 0) {
        
        static NSString *CellIdentifier = @"DayTitleCell";
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
        
        UILabel* dayLabel      = (UILabel*)[cell viewWithTag:100];
        UILabel* durationLabel = (UILabel*)[cell viewWithTag:101];
        
        NSArray* activitiesForDay = [self.activitiesByDay objectAtIndex:indexPath.section];
        
        TimeSlot* slot = ((Activity*)activitiesForDay[0]).timeslots.anyObject;
        NSString* dateString = [_dateFormatter stringFromDate:slot.start];
        dayLabel.text = dateString;
        
        // TODO duration
        double dailyDuration = 0;
        for (Activity* act in activitiesForDay) {
            dailyDuration += [act duration];
        }
        durationLabel.text = [NSString stringWithFormat:@"%.2f", dailyDuration];
        
        
    }
    // case day activity
    else {
        
        static NSString *CellIdentifier = @"ActivityCell";
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];

        Activity* activity = (Activity*)[self.activitiesByDay objectAtIndex:indexPath.section][indexPath.row - 1];
        
        UILabel* titleLabel      = (UILabel*)[cell viewWithTag:100];
        UILabel* durationLabel   = (UILabel*)[cell viewWithTag:101];
        UITextView* noteTextView = (UITextView*)[cell viewWithTag:102];
        
        // TODO dynamic height? -> cf CurrentListController
        
        Project* project = activity.project;
        titleLabel.text = [NSString stringWithFormat:@"%@ (%@)", project.name, project.subname];
        durationLabel.text = [NSString stringWithFormat:@"%.2f", [activity duration]];
        noteTextView.text = activity.note;
        
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0) {
        return 30;
    }
    else {
        // activity cell
        return 64;
    }
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a story board-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

 */

@end