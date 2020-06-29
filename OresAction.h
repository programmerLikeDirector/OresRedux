//
//  OresAction.h
//  ReduxForOC
//
//  Created by xiaoDi on 2020/6/13.
//  Copyright © 2020 XD. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    OresAction_updateLine,
    OresAction_Async
} OresActionType;

NS_ASSUME_NONNULL_BEGIN

@class OresAction;
@class OresStore;

@protocol OresActionProtocol <NSObject>

@required
@property (nonatomic,assign) OresActionType actionType;
@property (nonatomic,strong) id parameter;
/*
 标记action执行结束
 */
@property (nonatomic,assign) BOOL isFinished;
/*
 标记action将要执行
 */
@property (nonatomic,assign) BOOL itTimeToAction;
/*
 执行action
 */
- (void)executing;

@optional
/*
 与action建立依赖关系
 */
- (void)dependOnActions:(NSArray<OresAction *> *)actions;

@end
 



@protocol OresAsyncActionProtocol <NSObject>

@optional
- (void)commondWithStore:(OresStore *)store;

@end

@interface OresAction : NSObject<OresActionProtocol>

- (instancetype)initWithActionType:(OresActionType)type Para:(id)para;

@end


@interface OresAsyncAction : OresAction<OresAsyncActionProtocol>

@property (nonatomic,strong) NSMutableArray *responseArr;

@end



NS_ASSUME_NONNULL_END
