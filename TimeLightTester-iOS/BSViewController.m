//
//  BSViewController.m
//  TimeLightTester
//
//  Created by Sasmito Adibowo on 24-02-14.
//  Copyright (c) 2014 Basil Salad Software. All rights reserved.
//
//  Licensed under the BSD License <http://www.opensource.org/licenses/bsd-license>
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
//  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
//  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
//  SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
//  TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
//  BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
//  STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
//  THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "BSViewController.h"
#import "BSAudioLightController.h"

@interface BSViewController ()

@property (weak, nonatomic) IBOutlet UILabel *headphoneJackLabel;

@property (nonatomic,strong,readonly) BSAudioLightController* audioLightController;
@property (weak, nonatomic) IBOutlet UISlider *oscillationSlider;
@property (weak, nonatomic) IBOutlet UILabel *oscillationLabel;
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
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.oscillationSlider.value = self.audioLightController.twiddleFrequency;
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

- (IBAction)oscillationValueChanged:(id)sender
{
    float frequency = [(UISlider*)sender value];
    self.oscillationLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Oscillation frequency: %.2f", @"Label"),frequency];
    self.audioLightController.twiddleFrequency = frequency;
}

@end
