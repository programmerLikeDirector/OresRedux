# OresRedux
An OC version of the Redux framework

#可能是，最适合你的，优化臃肿controller的方法


​          当iOS技术进入2020年，当Swift成为主流，当SwiftUI，Combine等“新时代”的框架飞速发展时。面对现实中接手维护的Objective-C旧工程，甚至连最基础的MVC分层都没做好，Controller中混杂着繁复的接口嵌套，view修改散落在各个接口回调中，头疼的是view中UI的写法更是杂乱，牵一发而动全身，修改起来极为耗时耗力。

​         **把代码写得便于维护，省出时间摸鱼不香嘛？**

​         除了抱怨旧工程臃肿以外，还能做些什么呢。 由于不是重构代码，仅仅是迭代维护新功能，考虑到如果引入“主流”的MVVM框架，对view的入侵较大，时间不够充裕。如果暂时不改动view，而专注于整治Controller中散落的各个接口，整理数据流，应该是个可行的方式。

​        onecat的这篇文章给了我最大的启发：

​        [单向数据流动的函数式 View Controller](]https://onevcat.com/2017/07/state-based-viewcontroller/ )

​        关于文中提到的Redux框架思想，还可以参看下面几篇文章：

​        [Redux入门教程](http://www.ruanyifeng.com/blog/2016/09/redux_tutorial_part_one_basic_usages.html)

​       [基于Redux思想编写高度可测试的iOS代码](https://www.jianshu.com/p/5da027d606e1)

​        [Redux 中文文档](http://cn.redux.js.org)

这几位大🐂讲解的很详细了，我也不会比这几位把理论讲述得更清晰了，若想仔细了解Redux，劳驾各位移步上述链接。

​         回到onecat的代码，让我使用起来感到不适的是处理异步状态的写法，在reducer中“外挂”一个command。结合实际的工程，梳理了下思路，一种更自定义Redux的写法是：

1. reducer就是仅仅用来处理同步action，更改State中存储的数据。
2. 异步action能单独整理归纳。
3. 开发者仅仅在发出action的地方考虑创建异步或者同步action，并且都能用Store的dispatchAction方法执行action。
4. 能在语法上更简单地处理action之间的串行关系。

​        前两项比较好处理，先创建基本action协议

```objective-c
typedef enum : NSUInteger {
    OresAction_Test,
    OresAction_Async
} OresActionType;

@protocol OresActionProtocol <NSObject>

@required
@property (nonatomic,assign) OresActionType actionType;
@property (nonatomic,strong) id parameter;

@end
```

​       每个action都有类型和参数两个属性，分别创建基础action和异步action两个类，在异步action的实现中，默认设置为异步actionType        

```objective-c
@interface OresAction : NSObject<OresActionProtocol>

- (instancetype)initWithActionType:(OresActionType)type Para:(id)para;

@end


@interface OresAsyncAction : OresAction
@end

@implementation OresAsyncAction

- (instancetype)init {
  if (self = [super init]) {
      self.actionType = OresAction_Async;
  }
  return self;
  }
@end
```

​       考虑到测试方便和数据归纳统一，所有异步action所需要的参数设计存储在State中，统一给异步action添加一个执行方法，将Store作为参数传递，以便获取State存储的参数。

```objective-c
@protocol OresAsyncActionProtocol <NSObject>

@optional

- (void)commondWithStore:(OresStore *)store;

@end

@interface OresAsyncAction : OresAction<OresAsyncActionProtocol>

@end
```

​       在使用异步action时，就可以根据不同接口需求分别创建管理。

```objective-c
@interface TestAsyncRequestAction : OresAsyncAction
@end

@implementation TestAsyncRequestAction

- (void)commondWithStore:(OresStore *)store {
  NSLog(@"测试参数:%@",store.state.testPara);
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
    NSLog(@"异步回调");
  });
  }

@end
```

​       这样，前两项就搞定了。

​       接下来，先处理较为简单的同步串行action。需要让A依赖于B，那A就得知道B什么时候完成。给Action添加一个标记属性，增加一个关联其他action的方法。

```objc
@protocol OresActionProtocol <NSObject>
///···
@property (nonatomic,assign) BOOL isFinished;
@optional

- (void)dependOnActions:(NSArray<OresAction *> *)actions;
  @end

@implementation OresAction

- (void)dependOnActions:(NSArray<OresAction *> *)actions {
  if (self.dependActions.count > 0) {
      [self.dependActions addObjectsFromArray:actions];
      for (id action in self.dependActions) {
          [action addObserver:self forKeyPath:@"isFinished" options:NSKeyValueObservingOptionNew context:nil];
      }
  }
  }

- (NSMutableArray *)dependActions {
  if (nil == _dependActions) {
      _dependActions = [NSMutableArray array];
  }
  return _dependActions;
  }
@end

```

​      可以看到，实现关联action，最关键的就是用一个数组持有它，并用KVO监听“isFinished”字段。考虑到action可能依赖于多个action，dependOn方法传入一个action数组。当监听到action执行完时：

```objective-c
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"isFinished"] && [change[@"new"]boolValue]) {
        [object removeObserver:self forKeyPath:@"isFinished"];
        [self.dependActions removeObject:object];
    }
    
    if (self.dependActions.count <= 0) {
        //执行action
    }
}
```

​       回到上述的第3条问题，我们想用dispatchAction作为统一的执行入口，在action内部无法调用store的方法。解决方法同理，让store监听每一个action。并且方便一次发出多个action，store.h文件暴露给外部调用的dispatch方法，参数传入action数组。完整store和action调用如下:

```objective-c
@protocol OresActionProtocol <NSObject>
///···
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
  
@implementation OresAction
  
- (void)executing {
    if (self.dependActions.count <= 0) {
        self.itTimeToAction = YES;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
  ///···
    if (self.dependActions.count <= 0) {
        //执行action
        self.itTimeToAction = YES;
    }
}

@end

```

```objective-c
@interface OresStore : NSObject

@property (nonatomic,strong,readonly) OresState *state;
@property (nonatomic,strong) NSMutableArray *executingActions;

- (instancetype)initWithReducer:(Reducer)reducer initialState:(OresState *)state;

- (void)dispatchActions:(NSArray *)actionArr;

@end

@implementation OresStore

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
  if ([keyPath isEqualToString:@"itTimeToAction"]) {
      [object removeObserver:self forKeyPath:@"itTimeToAction"];
      [self.executingActions removeObject:object];
      [self dispatch:object];
  }
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

@end
```

​       然后记得在异步Action执行完毕时，修改"isFinished"。

       ```objective-c
@implementation TestAsyncRequestAction

- (void)commondWithStore:(OresStore *)store {
NSLog(@"测试参数:%@",store.state.testPara);
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
  NSLog(@"异步回调");
  self.isFinished = YES;
});
}

@end
       ```

​       现在还剩最后一个问题有待处理，也是我还一直在思考的问题。

​       之前说到，异步action所需的参数从state中获取，那同步action的参数呢？上述代码可以看出，action是带着一个parameter属性，在reducer中作更新state使用。考虑到异步action+同步action，同步action需要异步action回调之后的数据做参数的情况，给异步action增加一个response属性：

```objective-c
@interface OresAsyncAction : OresAction<OresAsyncActionProtocol>

@property (nonatomic,strong) NSMutableArray *responseArr;

@end
```

​       因为有可能需要多个参数的情况，所以将response设置成了Array类型。那么，一个简单的关联Action完整调用如下：

```objective-c
    TestAsyncRequestCodeAction *beforeAction = [[TestAsyncRequestCodeAction alloc]init];

    OresAction *updateAction = [[OresAction alloc]initWithActionType:OresAction_updateLine Para:beforeAction.responseArr];
  
    [updateAction dependOnActions:@[beforeAction]];

    [self.store dispatchActions:@[beforeAction,updateAction]];
```

```objective-c
@implementation TestAsyncRequestCodeAction

- (void)commondWithStore:(OresStore *)store {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
        [self.responseArr addObject:@"3"];
        self.isFinished = YES;
    });
}

@end
```

```objective-c
- (Reducer)reducer {
    Reducer reducer = ^(OresState *state,OresAction *action) {
        OresState *previousState = state;
        OresState *currentState  = [previousState copy];

        switch (action.actionType) {
            case OresAction_updateLine: {
                if ([action.parameter isKindOfClass:[NSMutableArray class]]) {
                    NSMutableArray *paraArr = action.parameter;
                    currentState.code = paraArr.firstObject;
                }else {
                    currentState.code = action.parameter;
                }
                break;
            }
                
        }
        
        return currentState;
    };
    return reducer;
}
```

​       这样带来的最不友好的问题就是，在更新state数据时，需要开发者自己判断参数是不是responseArr，并且多个参数的情况还要自己限定好每个参数在responseArr中的角标，非常难受。但是还没想到其他写法，😭。

​       最后，在写这篇记录，查相关资料时发现了另外一个OC版本的Redux框架，还实现了Redux中重要的Middleware功能！讲道理，这个Middleware的写法我也是看了好久才明白。与之比较，我这个写的就是野路子。链接如下，十分推荐：

​      [ReduxDemo](https://github.com/DanboDuan/ReduxDemo)

​      
