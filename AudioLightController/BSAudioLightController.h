//
//  BSAudioLightController.h
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

#import <Foundation/Foundation.h>

// ---

typedef enum {
    BSAudioLightItemNone    = 0,
    BSAudioLightItemGreen   = 1,
    BSAudioLightItemYellow  = 1 << 1,
    BSAudioLightItemRed     = 1 << 2,
    BSAudioLightItemBuzzer  = 1 << 3,
    BSAudioLightItemMax     = 1 << 4
} BSAudioLightItem;


// ---


@interface BSAudioLightController : NSObject

-(void) audioLightItem:(BSAudioLightItem) item setActive:(BOOL) active;

-(BOOL) enabled;

@end

extern NSString* const BSAudioLightAvailabilityNotification;
extern NSString* const BSAudioLightAvailabilityKey;

extern NSString* const BSAudioLightEnabledPrefKey;
