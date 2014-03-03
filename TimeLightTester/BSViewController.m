//
//  BSViewController.m
//  TimeLightTester
//
//  Created by Sasmito Adibowo on 24-02-14.
//  Copyright (c) 2014 Basil Salad Software. All rights reserved.
//

#import "BSViewController.h"
#import "BSAudioLightController.h"

@interface BSViewController ()

@property (weak, nonatomic) IBOutlet UILabel *headphoneJackLabel;

@property (nonatomic,strong,readonly) BSAudioLightController* audioLightController;
@end

@implementation BSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [self audioLightController];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Property Access

@synthesize audioLightController = _audioLightController;

-(BSAudioLightController *)audioLightController
{
    if (!_audioLightController) {
        _audioLightController = [BSAudioLightController new];
    }
    return _audioLightController;
}

@end
