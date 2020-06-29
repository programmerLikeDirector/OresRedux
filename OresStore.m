//
//  OresStore.h
//  ReduxForOC
//
//  Created by xiaoDi on 2020/6/13.
//  Copyright © 2020 XD. All rights reserved.
//

#import "OresStore.h"
#import "OresAction.h"

@interface OresStore ()

@property (nonatomic,copy) Reducer reducer;
@property (nonatomic,strong) NSMutableArray<SubscriberBlock> *subscribers;



@end

@implementation OresStore

- (instancetype)initWithReducer:(Reducer)reducer initialState:(OresState *)state {
    if (self = [super init]) {
        self.reducer = reducer;
        _state       = state;
    }
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"itTimeToAction"]) {
        [object removeObserver:self forKeyPath:@"itTimeToAction"];
        [self.executingActions removeObject:object];
        [self dispatch:object];
    }
}

- (void)bindSubscriber:(SubscriberBlock)sub {
    [self.subscribers addObject:sub];
}

- (void)dispatchActions:(NSArray *)actionArr {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self.executingActions addObjectsFromArray:actionArr];
        
        for (id action in actionArr) {
            [action addObserver:self forKeyPath:@"itTimeToAction" options:NSKeyValueObservingOptionNew context:nil];
        }
        
        for (id action in actionArr) {
            [action performSelector:@selector(executing)];
        }
    });
}

- (void)dispatch:(OresAction *)action {
    if (action.actionType == OresAction_Async) {
        //异步action,先执行异步任务
        OresAsyncAction *async = (OresAsyncAction *)action;
        [async commondWithStore:self];
        return;
    }
    //同步action，更新state存储数据
    OresState *previousState = self.state;
    OresState *nextState     = self.reducer(previousState,action);
    _state                   = nextState;
    for (SubscriberBlock subscriber in self.subscribers) {
        subscriber(previousState,nextState);
    }
    action.isFinished      = YES;
}

- (void)unSubscriber {
    [self.subscribers removeAllObjects];
}

- (NSMutableArray<SubscriberBlock> *)subscribers {
    if (nil == _subscribers) {
        _subscribers = [NSMutableArray array];
    }
    return _subscribers;
}

- (NSMutableArray *)executingActions {
    if (nil == _executingActions) {
        _executingActions = [NSMutableArray array];
    }
    return _executingActions;
}

- (void)dealloc {
    [self unSubscriber];
}

@end
