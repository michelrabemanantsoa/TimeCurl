//
//  AddProjectController.h
//  TimeWarp
//
//  Created by pat on 17.06.2013.
//  Copyright (c) 2013 zuehlke. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import "Project.h"
#import "SAMTextView.h"

@class TPKeyboardAvoidingScrollView;

@interface NewProjectController : UIViewController <NSFetchedResultsControllerDelegate>

- (IBAction)donePressed:(id) sender;

@property (nonatomic, strong) Project* project;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *subviewWidthConstraint;

@property (weak, nonatomic) IBOutlet UITextField* name;
@property (weak, nonatomic) IBOutlet UITextField* subname;
@property (weak, nonatomic) IBOutlet SAMTextView* note;
@property (weak, nonatomic) IBOutlet UIImageView *iconView;
@property (weak, nonatomic) IBOutlet UILabel *iconLabel;
@property (weak, nonatomic) IBOutlet UIButton *iconButton;

@end
