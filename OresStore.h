//
//  OresStore.h
//  ReduxForOC
//
//  Created by xiaoDi on 2020/6/13.
//  Copyright © 2020 XD. All rights reserved.
//

#import <Foundation/Foundation.h>

@class OresState;
@class OresAction;

NS_ASSUME_NONNULL_BEGIN

typedef OresState *_Nullable(^Reducer)(OresState *state,OresAction *action);

typedef void(^SubscriberBlock)(OresState *oldState, OresState *newState);

@interface OresStore : NSObject

@property (nonatomic,strong,readonly) OresState *state;
@property (nonatomic,strong) NSMutableArray *executingActions;

- (instancetype)initWithReducer:(Reducer)reducer initialState:(OresState *)state;

- (void)dispatchActions:(NSArray *)actionArr;

- (void)bindSubscriber:(SubscriberBlock)sub;

- (void)unSubscriber;

@end

NS_ASSUME_NONNULL_END
