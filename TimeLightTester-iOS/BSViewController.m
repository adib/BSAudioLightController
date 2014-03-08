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

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(audioLightAvailability:) name:BSAudioLightAvailabilityNotification object:nil];
    
    BOOL audioLightEnabled = [self.audioLightController enabled];
    self.headphoneJackLabel.text = audioLightEnabled ? NSLocalizedString(@"Audio Light Enabled",@"Indicator")  :NSLocalizedString(@"Audio Light Disabled",@"Indicator");

    self.headphoneJackLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Enabled: %@", @"Indicator"),@([self.audioLightController enabled])];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    // Dispose of any resources that can be recreated.
}

-(void) audioLightAvailability:(NSNotification*) notification
{
    BOOL audioLightEnabled = [notification.userInfo[BSAudioLightAvailabilityKey] boolValue];
    self.headphoneJackLabel.text = audioLightEnabled ? NSLocalizedString(@"Audio Light Enabled",@"Indicator")  :NSLocalizedString(@"Audio Light Disabled",@"Indicator");
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


- (IBAction)greenLightValueChanged:(id)sender
{
    BOOL active = [sender isOn];
    [self.audioLightController audioLightItem:BSAudioLightItemGreen setActive:active];
}

- (IBAction)yellowLightValueChanged:(id)sender
{
    BOOL active = [sender isOn];
    [self.audioLightController audioLightItem:BSAudioLightItemYellow setActive:active];
    
}

- (IBAction)redLightValueChanged:(id)sender
{
    BOOL active = [sender isOn];
    [self.audioLightController audioLightItem:BSAudioLightItemRed setActive:active];
    
}

- (IBAction)buzzerValueChanged:(id)sender
{
    BOOL active = [sender isOn];
    [self.audioLightController audioLightItem:BSAudioLightItemBuzzer setActive:active];
}

@end
