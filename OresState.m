//
//  OresState.h
//  ReduxForOC
//
//  Created by xiaoDi on 2020/6/13.
//  Copyright © 2020 XD. All rights reserved.
//

#import "OresState.h"

@implementation OresState

- (id)copyWithZone:(NSZone *)zone {
    OresState *state = [OresState new];
    state.code = self.code;
    
    return state;
}

@end
