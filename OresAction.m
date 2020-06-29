//
//  OresAction.h
//  ReduxForOC
//
//  Created by xiaoDi on 2020/6/13.
//  Copyright © 2020 XD. All rights reserved.
//

#import "OresAction.h"
#import "OresStore.h"

@interface OresAction ()

@property (nonatomic,strong) NSMutableArray *dependActions;

@end

@implementation OresAction

@synthesize actionType;
@synthesize parameter;
@synthesize isFinished;
@synthesize itTimeToAction;

- (instancetype)initWithActionType:(OresActionType)type Para:(id)para {
    if (self = [super init]) {
        self.actionType = type;
        self.parameter  = para;
        self.isFinished = NO;
        self.itTimeToAction = NO;
    }
    return self;
}

- (void)dependOnActions:(NSArray<OresAction *> *)actions {
    if (self.dependActions.count > 0) {
        [self.dependActions addObjectsFromArray:actions];
        for (id action in self.dependActions) {
            [action addObserver:self forKeyPath:@"isFinished" options:NSKeyValueObservingOptionNew context:nil];
        }
    }
}

- (void)executing {
    if (self.dependActions.count <= 0) {
        self.itTimeToAction = YES;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"isFinished"] && [change[@"new"]boolValue]) {
        [object removeObserver:self forKeyPath:@"isFinished"];
        [self.dependActions removeObject:object];
    }
    
    if (self.dependActions.count <= 0) {
        //执行action
        self.itTimeToAction = YES;
    }
}

- (NSMutableArray *)dependActions {
    if (nil == _dependActions) {
        _dependActions = [NSMutableArray array];
    }
    return _dependActions;
}

- (void)dealloc {
    NSLog(@"\nAction销毁 %@\n",self);
}

@end


@implementation OresAsyncAction

- (instancetype)init {
    if (self = [super init]) {
        self.actionType = OresAction_Async;
        self.isFinished = NO;
        self.itTimeToAction = NO;
    }
    return self;
}

- (NSMutableArray *)responseArr {
    if (nil == _responseArr) {
        _responseArr = [NSMutableArray array];
    }
    return _responseArr;
}

@end


