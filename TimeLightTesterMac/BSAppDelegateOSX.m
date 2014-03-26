//
//  BSAppDelegate.m
//  TimeLightTesterMac
//
//  Created by Sasmito Adibowo on 26-03-14.
//  Copyright (c) 2014 Basil Salad Software. All rights reserved.
//

#import "BSAppDelegateOSX.h"
#import "BSAudioLightController.h"

@interface BSAppDelegateOSX ()
@property (nonatomic,strong,readonly) BSAudioLightController* audioLightController;
@property (weak) IBOutlet NSTextField *headphoneJackLabel;
@property (weak) IBOutlet NSTextField *oscillationLabel;

@end

@implementation BSAppDelegateOSX

#pragma mark Notification Handlers

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setBool:YES forKey:BSAudioLightEnabledPrefKey];

    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(audioLightAvailability:) name:BSAudioLightAvailabilityNotification object:nil];
    
    BOOL audioLightEnabled = [self.audioLightController enabled];
    self.headphoneJackLabel.stringValue = audioLightEnabled ? NSLocalizedString(@"Audio Light Enabled",@"Indicator")  :NSLocalizedString(@"Audio Light Disabled",@"Indicator");
    
}




-(void) audioLightAvailability:(NSNotification*) notification
{
    BOOL audioLightEnabled = [notification.userInfo[BSAudioLightAvailabilityKey] boolValue];
    self.headphoneJackLabel.stringValue = audioLightEnabled ? NSLocalizedString(@"Audio Light Enabled",@"Indicator")  :NSLocalizedString(@"Audio Light Disabled",@"Indicator");
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


#pragma mark Action Handler


- (IBAction)greenLightValueChanged:(id)sender
{
    BOOL active = [(NSButton*)sender state] == NSOnState;
    [self.audioLightController audioLightItem:BSAudioLightItemGreen setActive:active];
}

- (IBAction)yellowLightValueChanged:(id)sender
{
    BOOL active = [(NSButton*)sender state] == NSOnState;
    [self.audioLightController audioLightItem:BSAudioLightItemYellow setActive:active];
    
}

- (IBAction)redLightValueChanged:(id)sender
{
    BOOL active = [(NSButton*)sender state] == NSOnState;
    [self.audioLightController audioLightItem:BSAudioLightItemRed setActive:active];
    
}

- (IBAction)buzzerValueChanged:(id)sender
{
    BOOL active = [(NSButton*)sender state] == NSOnState;
    [self.audioLightController audioLightItem:BSAudioLightItemBuzzer setActive:active];
}

- (IBAction)oscillationValueChanged:(id)sender
{
    float frequency = [(NSSlider*)sender floatValue];
    self.oscillationLabel.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Oscillation frequency: %.2f", @"Label"),frequency];
    self.audioLightController.twiddleFrequency = frequency;
}
@end
