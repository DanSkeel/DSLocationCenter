//
//  ViewController.m
//  LocationCenterDemo
//
//  Created by Danila Shikulin on 04.01.15.
//
//

#import "ViewController.h"

#import "DSLocationCenter.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UIButton *findMeButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;
@property (weak, nonatomic) DSLocationRequest *locationRequest;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)printStringToTextView:(NSString *)string {
    self.textView.text = [self.textView.text stringByAppendingFormat:@"\n\n%@", string];
    [self.textView scrollRangeToVisible:NSMakeRange(self.textView.text.length-1, 1)];
}

- (void)makeLocationRequest {
    DSLocationCenter *locationCenter = [DSLocationCenter sharedLocationCenter];
    DSLocationRequest *locRequest = [DSLocationRequest request];
    locRequest.timeRelevance = 60;
    locRequest.timeOut = 30;
    locRequest.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
    locRequest.minAccuracy = kCLLocationAccuracyThreeKilometers;
    __weak ViewController *wself = self;
    [locRequest setNewBestLocationBlock:^(CLLocation *newBestLocation, BOOL *finish) {
        [wself printStringToTextView:[NSString stringWithFormat:@"New best location: %@", newBestLocation]];
    }];
    [locRequest setFinishBlock:^(DSLRFinishStatus finishStatus, NSError *err) {
        self.findMeButton.enabled = YES;
        [self.spinner stopAnimating];
        NSString *statusStr = [DSLocationRequest stringForFinishStatus:finishStatus];
        NSMutableString *message = [NSMutableString stringWithFormat:@"Finished with status: %@", statusStr];
        if (err) {
            [message appendFormat:@"\nerror: %@", err];
        }
        [wself printStringToTextView:message];
    }];
    [self printStringToTextView:@"Will start processing request"];
    [self.spinner startAnimating];
    [locationCenter processRequest:locRequest];
    self.locationRequest = locRequest;
}

- (IBAction)findMeButtonPressed:(id)sender {
    self.findMeButton.enabled = NO;
    [self makeLocationRequest];
}


@end
