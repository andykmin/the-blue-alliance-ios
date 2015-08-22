//
//  TeamViewController.m
//  the-blue-alliance-ios
//
//  Created by Zach Orr on 6/7/15.
//  Copyright (c) 2015 The Blue Alliance. All rights reserved.
//

#import "TeamViewController.h"
#import "TBAEventsViewController.h"
#import "TBAInfoViewController.h"
#import "TBAMediaCollectionViewController.h"
#import "Team.h"
#import "Team+Fetch.h"
#import "Event+Fetch.h"
#import "Media.h"
#import "Media+Fetch.h"

static NSString *const EventsViewControllerEmbed    = @"EventsViewControllerEmbed";
static NSString *const InfoViewControllerEmbed      = @"InfoViewControllerEmbed";
static NSString *const MediaViewControllerEmbed     = @"MediaViewControllerEmbed";

typedef NS_ENUM(NSInteger, TBATeamDataType) {
    TBATeamDataTypeInfo = 0,
    TBATeamDataTypeEvents,
    TBATeamDataTypeMedia
};

@interface TeamViewController ()

@property (nonatomic, weak) IBOutlet UISegmentedControl *segmentedControl;
@property (nonatomic, strong) IBOutlet UIView *segmentedControlView;

@property (nonatomic, strong) TBAInfoViewController *infoViewController;
@property (nonatomic, weak) IBOutlet UIView *infoView;

@property (nonatomic, strong) TBAEventsViewController *eventsViewController;
@property (nonatomic, weak) IBOutlet UIView *eventsView;

@property (nonatomic, strong) TBAMediaCollectionViewController *mediaCollectionViewController;
@property (nonatomic, weak) IBOutlet UIView *mediaView;

@end

@implementation TeamViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    __weak typeof(self) weakSelf = self;
    self.refresh = ^void() {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        if (strongSelf.segmentedControl.selectedSegmentIndex == TBATeamDataTypeInfo) {
            [strongSelf refreshTeamInfo];
        } else if (strongSelf.segmentedControl.selectedSegmentIndex == TBATeamDataTypeEvents) {
            [strongSelf.eventsViewController hideNoDataView];
            [strongSelf refreshEvents];
        } else if (strongSelf.segmentedControl.selectedSegmentIndex == TBATeamDataTypeMedia) {
            [strongSelf.mediaCollectionViewController hideNoDataView];
            [strongSelf refreshMedia];
        }
    };
    
    self.yearSelected = ^void(NSUInteger selectedYear) {
        __strong typeof(weakSelf) strongSelf = weakSelf;

        [strongSelf cancelRefresh];

        strongSelf.currentYear = selectedYear;
        
        if (strongSelf.segmentedControl.selectedSegmentIndex == TBATeamDataTypeEvents) {
            [strongSelf.eventsViewController hideNoDataView];
            [strongSelf removeEvents];
            [strongSelf fetchEventsAndRefresh:YES];
        } else if (strongSelf.segmentedControl.selectedSegmentIndex == TBATeamDataTypeMedia) {
            [strongSelf.mediaCollectionViewController hideNoDataView];
            [strongSelf removeMedia];
            [strongSelf fetchMediaAndRefresh:YES];
        }
    };
    
    [self fetchYearsParticipatedAndRefresh:YES];
    [self fetchMediaAndRefresh:YES];

    [self styleInterface];
}

#pragma mark - Interface Methods

- (void)styleInterface {
    self.segmentedControlView.backgroundColor = [UIColor TBANavigationBarColor];
    self.navigationItem.title = [NSString stringWithFormat:@"Team %@", self.team.teamNumber];
}

- (void)updateInterface {
    if (self.segmentedControl.selectedSegmentIndex == TBATeamDataTypeInfo) {
        self.infoView.hidden = NO;
        self.eventsView.hidden = YES;
        self.mediaView.hidden = YES;
        
        [self fetchTeamAndRefresh:NO];
    } else if (self.segmentedControl.selectedSegmentIndex == TBATeamDataTypeEvents) {
        self.eventsView.hidden = NO;
        self.mediaView.hidden = YES;
        self.infoView.hidden = YES;
        
        [self fetchEventsAndRefresh:NO];
    } else {
        self.mediaView.hidden = NO;
        self.eventsView.hidden = YES;
        self.infoView.hidden = YES;
        
        [self fetchMediaAndRefresh:YES];
    }
}

- (IBAction)segmentedControlValueChanged:(id)sender {
    [self cancelRefresh];
    [self updateInterface];
}

#pragma mark - Team Info Refresh (Upstream) Data Methods

- (void)refreshTeamInfo {
    [self updateRefreshBarButtonItem:YES];

    [self refreshYearsParticipated];
    [self refreshTeam];
}

#pragma mark - Years Participated

- (void)fetchYearsParticipatedAndRefresh:(BOOL)refresh {
    NSArray *years = [self.team sortedYearsParticipated];
    if ([years count] == 0) {
        self.currentYear = 0;
        if (refresh) {
            [self refreshYearsParticipated];
        }
    } else {
        self.years = years;
        if (self.currentYear == 0) {
            self.currentYear = [(NSNumber *)[years firstObject] integerValue];
            [self fetchMediaAndRefresh:YES];
        }
    }
}

- (void)refreshYearsParticipated {
    __weak typeof(self) weakSelf = self;
    __block NSUInteger request = [[TBAKit sharedKit] fetchYearsParticipatedForTeamKey:self.team.key withCompletionBlock:^(NSArray *years, NSInteger totalCount, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        [strongSelf removeRequestIdentifier:request];
        
        if (!error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                strongSelf.team.yearsParticipated = years;
                [strongSelf fetchYearsParticipatedAndRefresh:NO];
                [strongSelf.persistenceController save];
            });
        }
    }];
    [self addRequestIdentifier:request];
}

#pragma mark - Team

- (void)fetchTeamAndRefresh:(BOOL)refresh {
    __weak typeof(self) weakSelf = self;
    [Team fetchTeamForKey:self.team.key fromContext:self.persistenceController.managedObjectContext checkUpstream:NO withCompletionBlock:^(Team *team, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf showErrorAlertWithMessage:@"Unable to fetch team info locally"];
            });
            return;
        }
        
        if (!team) {
            if (refresh) {
                [self refresh];
            }
        } else {
            strongSelf.team = team;
            strongSelf.infoViewController.team = team;
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf.infoViewController.tableView reloadData];
            });
        }
    }];
}

- (void)refreshTeam {
    __weak typeof(self) weakSelf = self;
    __block NSUInteger request = [[TBAKit sharedKit] fetchTeamForTeamKey:self.team.key withCompletionBlock:^(TBATeam *team, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        [strongSelf removeRequestIdentifier:request];
        
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf showErrorAlertWithMessage:@"Unable to reload team info"];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [Team insertTeamWithModelTeam:team inManagedObjectContext:strongSelf.persistenceController.managedObjectContext];
                [strongSelf fetchTeamAndRefresh:NO];
                [strongSelf.persistenceController save];
            });
        }
    }];
    [self addRequestIdentifier:request];
}

#pragma mark - Media

- (void)removeMedia {
    self.mediaCollectionViewController.media = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.mediaCollectionViewController.collectionView reloadData];
    });
}

- (void)fetchMediaAndRefresh:(BOOL)refresh {
    if (self.currentYear == 0) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    [Media fetchMediaForYear:self.currentYear forTeam:self.team fromContext:self.persistenceController.managedObjectContext withCompletionBlock:^(NSArray *media, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf showErrorAlertWithMessage:@"Unable to fetch team media locally"];
            });
            return;
        }
        
        if ([media count] == 0) {
            if (refresh) {
                [strongSelf refreshMedia];
            }
        } else {
            strongSelf.mediaCollectionViewController.media = media;
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf.mediaCollectionViewController.collectionView reloadData];
            });
        }
    }];
}

- (void)refreshMedia {
    if (self.currentYear == 0) {
        return;
    }
    __block NSInteger year = self.currentYear;
    
    __weak typeof(self) weakSelf = self;
    __block NSUInteger request = [[TBAKit sharedKit] fetchMediaForTeamKey:self.team.key andYear:self.currentYear withCompletionBlock:^(NSArray *media, NSInteger totalCount, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        [strongSelf removeRequestIdentifier:request];
        
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf showErrorAlertWithMessage:@"Unable to load team media"];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [Media insertMediasWithModelMedias:media forTeam:self.team andYear:year inManagedObjectContext:strongSelf.persistenceController.managedObjectContext];
                [strongSelf fetchMediaAndRefresh:NO];
                [strongSelf.persistenceController save];
            });
        }
    }];
    [self addRequestIdentifier:request];
}

#pragma mark - Events Data Methods

- (void)removeEvents {
    self.eventsViewController.events = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.eventsViewController.tableView reloadData];
    });
}

- (void)fetchEventsAndRefresh:(BOOL)refresh {
    if (self.currentYear == 0) {
        return;
    }
    
    NSArray *events = [self.team sortedEventsForYear:self.currentYear];
    
    if ([events count] == 0) {
        if (refresh) {
            [self refreshEvents];
        } else {
            [self removeEvents];
        }
    } else {
        self.eventsViewController.events = [Event sortedEventDictionaryFromEvents:events];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.eventsViewController.tableView reloadData];
        });
    }
}

- (void)refreshEvents {
    if (self.currentYear == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.eventsViewController showNoDataViewWithText:@"No year selected"];
        });
        return;
    }
    
    [self updateRefreshBarButtonItem:YES];

    __weak typeof(self) weakSelf = self;
    __block NSUInteger request = [[TBAKit sharedKit] fetchEventsForTeamKey:self.team.key andYear:self.currentYear withCompletionBlock:^(NSArray *events, NSInteger totalCount, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        [strongSelf removeRequestIdentifier:request];
        
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf.eventsViewController showNoDataViewWithText:@"Unable to load events for team"];
            });
        } else {
            NSArray *newEvents = [Event insertEventsWithModelEvents:events inManagedObjectContext:strongSelf.persistenceController.managedObjectContext];
            [strongSelf.team addEvents:[NSSet setWithArray:newEvents]];
            [strongSelf updateInterface];
            [strongSelf.persistenceController save];
        }
    }];
    [self addRequestIdentifier:request];
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:InfoViewControllerEmbed]) {
        self.infoViewController = segue.destinationViewController;
        self.infoViewController.team = self.team;
    } else if ([segue.identifier isEqualToString:EventsViewControllerEmbed]) {
        self.eventsViewController = segue.destinationViewController;
        self.eventsViewController.eventSelected = ^(Event *event) {
            NSLog(@"Selected event: %@", event.shortName);
        };
    } else if ([segue.identifier isEqualToString:MediaViewControllerEmbed]) {
        self.mediaCollectionViewController = segue.destinationViewController;
    }
}

@end
