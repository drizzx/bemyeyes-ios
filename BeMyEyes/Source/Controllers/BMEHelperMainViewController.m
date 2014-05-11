//
//  BMEHelperMainViewController.m
//  BeMyEyes
//
//  Created by Simon Støvring on 15/03/14.
//  Copyright (c) 2014 Be My Eyes. All rights reserved.
//

#import "BMEHelperMainViewController.h"
#import "BMEClient.h"
#import "BMEUser.h"
#import "BMEPointEntry.h"
#import "BMEPointLabel.h"
#import "BMEPointGraphView.h"
#import "NSDate+BMESnoozeRelativeDate.h"

#define BMEHelperSnoozeAmount0 0.0f
#define BMEHelperSnoozeAmount25 3600.0f
#define BMEHelperSnoozeAmount50 6 * 3600.0f
#define BMEHelperSnoozeAmount75 24 * 3600.0f
#define BMEHelperSnoozeAmount100 7 * 24 * 3600.0f

typedef NS_ENUM(NSInteger, BMESnoozeStep) {
    BMESnoozeStep0 = 0,
    BMESnoozeStep25,
    BMESnoozeStep50,
    BMESnoozeStep75,
    BMESnoozeStep100
};

@interface BMEHelperMainViewController () <UIGestureRecognizerDelegate>
@property (weak, nonatomic) IBOutlet UILabel *greetingLabel;

@property (weak, nonatomic) IBOutlet UILabel *pointTitleLabel;
@property (weak, nonatomic) IBOutlet BMEPointLabel *pointLabel;
@property (weak, nonatomic) IBOutlet BMEPointGraphView *pointGraphView;
@property (weak, nonatomic) IBOutlet UILabel *failedLoadingPointLabel;

@property (weak, nonatomic) IBOutlet UIView *snoozeSliderView;
@property (weak, nonatomic) IBOutlet UIImageView *snoozeStepImageView0;
@property (weak, nonatomic) IBOutlet UIImageView *snoozeStepImageView25;
@property (weak, nonatomic) IBOutlet UIImageView *snoozeStepImageView50;
@property (weak, nonatomic) IBOutlet UIImageView *snoozeStepImageView75;
@property (weak, nonatomic) IBOutlet UIImageView *snoozeStepImageView100;
@property (weak, nonatomic) IBOutlet UIImageView *snoozeThumbImageView;
@property (weak, nonatomic) IBOutlet UILabel *snoozeStatusLabel;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *scoreTitleLabelLeadingMarginConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *scoreTitleLabelWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *pointLabelWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *scoreTitlePointSpaceConstraint;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *snoozeStep0CenterMarginXConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *snoozeStep25CenterMarginXConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *snoozeStep50CenterMarginXConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *snoozeStep75CenterMarginXConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *snoozeStep100CenterMarginXConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *snoozeThumbCenterMarginXConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *snoozeThumbWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *snoozeSliderLineWidthConstraint;

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *pointActivityIndicator;

@property (assign, nonatomic) NSUInteger totalPoint;
@property (strong, nonatomic) NSArray *pointEntries;
@end

@implementation BMEHelperMainViewController

#pragma mark -
#pragma mark Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
 
    self.pointLabel.colors = @{ @(0.0f) : [UIColor colorWithRed:220.0f/255.0f green:38.0f/255.0f blue:38.0f/255.0f alpha:1.0f],
                                @(0.50f) : [UIColor colorWithRed:252.0f/255.0f green:197.0f/255.0f blue:46.0f/255.0f alpha:1.0f],
                                @(1.0f) : [UIColor colorWithRed:117.0f/255.0f green:197.0f/255.0f blue:27.0f/255.0f alpha:1.0f] };
 
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    panGesture.delegate = self;
    [self.view addGestureRecognizer:panGesture];
    
    [self displayGreeting];
    
    [self snapSnoozeSliderToStep:BMESnoozeStep0 animated:NO];
    
    [self reloadPoints];
}

- (void)dealloc {
    self.pointEntries = nil;
}

#pragma mark -
#pragma mark Private Methods

- (void)displayGreeting {
    NSArray *greetingFormats = @[ NSLocalizedStringFromTable(@"GREETING_1", @"BMEHelperMainViewController", @"Greeting for helper. %@ is replaced with the name."),
                                  NSLocalizedStringFromTable(@"GREETING_2", @"BMEHelperMainViewController", @"Greeting for helper. %@ is replaced with the name."),
                                  NSLocalizedStringFromTable(@"GREETING_3", @"BMEHelperMainViewController", @"Greeting for helper. %@ is replaced with the name."),
                                  NSLocalizedStringFromTable(@"GREETING_4", @"BMEHelperMainViewController", @"Greeting for helper. %@ is replaced with the name."),
                                  NSLocalizedStringFromTable(@"GREETING_5", @"BMEHelperMainViewController", @"Greeting for helper. %@ is replaced with the name.") ];
    if (greetingFormats) {
        NSString *name = [BMEClient sharedClient].currentUser.firstName;
        NSString *greetingFormat = greetingFormats[arc4random() % [greetingFormats count]];
        self.greetingLabel.text = [NSString stringWithFormat:greetingFormat, name];
    } else {
        self.greetingLabel.text = nil;
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateChanged) {
        CGPoint pos = [gestureRecognizer locationInView:self.snoozeSliderView];
        CGFloat newPos = pos.x - self.snoozeThumbWidthConstraint.constant * 0.50f;
        self.snoozeThumbCenterMarginXConstraint.constant = MIN(MAX(newPos, self.snoozeStep0CenterMarginXConstraint.constant), self.snoozeStep100CenterMarginXConstraint.constant);
        [self.view layoutIfNeeded];
    } else if (gestureRecognizer.state == UIGestureRecognizerStateEnded ||
               gestureRecognizer.state == UIGestureRecognizerStateFailed ||
               gestureRecognizer.state == UIGestureRecognizerStateCancelled) {
        [self snapSnoozeSliderThumb:YES];
    }
}

- (void)snapSnoozeSliderThumb:(BOOL)animated {
    CGFloat pos = self.snoozeThumbCenterMarginXConstraint.constant;
    CGFloat lineWidth = self.snoozeSliderLineWidthConstraint.constant;
    if (pos < lineWidth * 0.125f) {
        [self snapSnoozeSliderToStep:BMESnoozeStep0 animated:animated];
    } else if (pos < lineWidth * 0.375f) {
        [self snapSnoozeSliderToStep:BMESnoozeStep25 animated:animated];
    } else if (pos < lineWidth * 0.625f) {
        [self snapSnoozeSliderToStep:BMESnoozeStep50 animated:animated];
    } else if (pos < lineWidth * 0.875f) {
        [self snapSnoozeSliderToStep:BMESnoozeStep75 animated:animated];
    } else {
        [self snapSnoozeSliderToStep:BMESnoozeStep100 animated:animated];
    }
}

- (void)snapSnoozeSliderToStep:(BMESnoozeStep)step animated:(BOOL)animated {
    CGFloat snappedPos = 0.0f;
    NSTimeInterval snoozeAmount = 0.0f;
    switch (step) {
        case BMESnoozeStep0:
            snappedPos = self.snoozeStep0CenterMarginXConstraint.constant;
            snoozeAmount = BMEHelperSnoozeAmount0;
            break;
        case BMESnoozeStep25:
            snappedPos = self.snoozeStep25CenterMarginXConstraint.constant;
            snoozeAmount = BMEHelperSnoozeAmount25;
            break;
        case BMESnoozeStep50:
            snappedPos = self.snoozeStep50CenterMarginXConstraint.constant;
            snoozeAmount = BMEHelperSnoozeAmount50;
            break;
        case BMESnoozeStep75:
            snappedPos = self.snoozeStep75CenterMarginXConstraint.constant;
            snoozeAmount = BMEHelperSnoozeAmount75;
            break;
        case BMESnoozeStep100:
            snappedPos = self.snoozeStep100CenterMarginXConstraint.constant;
            snoozeAmount = BMEHelperSnoozeAmount100;
            break;
        default:
            break;
    }
    
    if (snoozeAmount > 0) {
        NSString *snoozeAmountText = [[NSDate dateWithTimeIntervalSinceNow:snoozeAmount] BMESnoozeRelativeDate];
        self.snoozeStatusLabel.text = [NSString stringWithFormat:NSLocalizedStringFromTable(@"SNOOZE_STATUS_TEXT", @"BMEHelperMainViewController", @"Format for snooze status text. %@ is replaced with the snooze amount."), snoozeAmountText];
    } else {
        self.snoozeStatusLabel.text = NSLocalizedStringFromTable(@"SNOOZE_STATUS_NOT_SNOOZING_TEXT", @"BMEHelperMainViewController", @"Snooze status text when not snoozing");
    }
    
    self.snoozeThumbCenterMarginXConstraint.constant = snappedPos;
    
    if (animated) {
        [UIView animateWithDuration:0.30f delay:0.0f usingSpringWithDamping:0.60f initialSpringVelocity:1.0f options:UIViewAnimationOptionCurveEaseOut animations:^{
            [self.view layoutIfNeeded];
        } completion:nil];
    } else {
        [self.view layoutIfNeeded];
    }
}

- (void)layoutPoint {
    NSString *pointText = [NSString stringWithFormat:@"%i", self.totalPoint];
    CGRect pointRect = [pointText boundingRectWithSize:CGSizeMake(MAXFLOAT, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{ NSFontAttributeName : self.pointLabel.font } context:nil];
    self.pointLabelWidthConstraint.constant = CGRectGetWidth(pointRect) * 1.20f; // Add extra width for zoom animation
    [self.view layoutIfNeeded];
    
    CGFloat totalWidth = self.scoreTitleLabelWidthConstraint.constant + self.scoreTitlePointSpaceConstraint.constant + self.pointLabelWidthConstraint.constant;
    self.scoreTitleLabelLeadingMarginConstraint.constant = (CGRectGetWidth(self.view.bounds) - totalWidth) * 0.50f;
    [self.view layoutIfNeeded];
}

- (void)reloadPoints {
    [self.pointActivityIndicator startAnimating];
    [UIView animateWithDuration:0.30f animations:^{
        self.failedLoadingPointLabel.alpha = 0.0f;
        self.pointTitleLabel.alpha = 0.0f;
        self.pointLabel.alpha = 0.0f;
        self.pointGraphView.alpha = 0.0f;
    }];
    
    __block BOOL failedLoadingPoints = NO;
    __block BOOL totalLoaded = NO;
    __block BOOL daysLoaded = NO;
    
    void(^completion)(void) = ^{
        [self.pointActivityIndicator stopAnimating];
            
        if (failedLoadingPoints) {
            [self showFailedLoadingPoint];
        } else if (totalLoaded && daysLoaded) {
            [self showPoint];
        }
    };
    
    [[BMEClient sharedClient] loadTotalPoint:^(NSUInteger points, NSError *error) {
        if (error) {
            NSLog(@"Could not load total point: %@", error);
            
            failedLoadingPoints = YES;
        } else {
            totalLoaded = YES;
            self.totalPoint = points;
        }
        
        completion();
    }];
    
    [[BMEClient sharedClient] loadPointForDays:30 completion:^(NSArray *entries, NSError *error) {
        if (error) {
            NSLog(@"Could not load point for days: %@", error);
            
            failedLoadingPoints = YES;
        } else {
            daysLoaded = YES;
            self.pointEntries = entries;
        }
        
        completion();
    }];
}

- (void)showPoint {
    for (BMEPointEntry *pointEntry in self.pointEntries) {
        [self.pointGraphView addPoint:pointEntry.point atDate:pointEntry.date];
    }
    
    [self.pointGraphView draw];
    [self.pointLabel setPoint:self.totalPoint animated:YES];
    [self layoutPoint];

    self.pointTitleLabel.alpha = 0.0f;
    self.pointLabel.alpha = 0.0f;
    self.pointGraphView.alpha = 0.0f;
    
    self.pointTitleLabel.hidden = NO;
    self.pointLabel.hidden = NO;
    self.pointGraphView.hidden = NO;
    
    [UIView animateWithDuration:0.30f animations:^{
        self.pointTitleLabel.alpha = 1.0f;
        self.pointLabel.alpha = 1.0f;
        self.pointGraphView.alpha = 1.0f;
        self.failedLoadingPointLabel.alpha = 0.0f;
    } completion:^(BOOL finished) {
        self.failedLoadingPointLabel.hidden = YES;
    }];
}

- (void)showFailedLoadingPoint {
    self.failedLoadingPointLabel.alpha = 0.0f;
    self.failedLoadingPointLabel.hidden = NO;
    
    [UILabel animateWithDuration:0.30f animations:^{
        self.pointTitleLabel.alpha = 0.0f;
        self.pointLabel.alpha = 0.0f;
        self.pointGraphView.alpha = 0.0f;
        self.failedLoadingPointLabel.alpha = 1.0f;
    } completion:^(BOOL finished) {
        self.pointTitleLabel.hidden = YES;
        self.pointLabel.hidden = YES;
        self.pointGraphView.hidden = YES;
    }];
}

#pragma mark -
#pragma mark Gesture Recognizer Delegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    CGPoint pos = [gestureRecognizer locationInView:self.snoozeSliderView];
    return CGRectContainsPoint(self.snoozeThumbImageView.frame, pos);
}

@end