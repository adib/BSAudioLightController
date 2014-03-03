//
//  BSAudioLightController.h
//  TimeLightTester
//
//  Created by Sasmito Adibowo on 24-02-14.
//  Copyright (c) 2014 Basil Salad Software. All rights reserved.
//

#import <Foundation/Foundation.h>
// ---



typedef enum {
    BSAudioLightItemNone    = 0,
    BSAudioLightItemGreen   = 1,
    BSAudioLightItemYellow  = 1 << 1,
    BSAudioLightItemRed     = 1 << 2,
    BSAudioLightItemBuzzer  = 1 << 3
} BSAudioLightItem;


// ---


@interface BSAudioLightController : NSObject

-(void) audioLightItem:(BSAudioLightItem) item setActive:(BOOL) active;
                        
@end

extern NSString* const BSAudioLightControllerAvailabilityNotification;
extern NSString* const BSAudioLightControllerAvailabilityKey;

extern NSString* const BSAudioLightEnabledPrefKey;
