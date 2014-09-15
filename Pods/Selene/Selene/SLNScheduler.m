//
//  Selene
//
//  Copyright (c) 2014 LinkedIn Corp. All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//

#import "SLNScheduler.h"
#import "SLNTaskProtocol.h"

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Convert your project to ARC or specify the -fobjc-arc flag.
#endif

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Convert your project to ARC or specify the -fobjc-arc flag.
#endif

#ifdef DEBUG
#define SLN_ENABLE_LOGGING 1
#else
#define SLN_ENABLE_LOGGING 0
#endif

#if SLN_ENABLE_LOGGING != 0
// First, check if we can use Cocoalumberjack for logging
#ifdef LOG_VERBOSE
extern int ddLogLevel;
#define SLNLog(...) DDLogVerbose(__VA_ARGS__)
#else
#define SLNLog(...) NSLog(@"%s(%p) %@", __PRETTY_FUNCTION__, self, [NSString stringWithFormat:__VA_ARGS__])
#endif
#else
#define SLNLog(...) ((void)0)
#endif

// Used as key for storing the last execution time of tsaks, in NSUserDefaults
static NSString * const kSLNExecutionSchedule = @"kSLNExecutionSchedule";
static NSString * const kSLNRecentResponseTimes = @"kSLNRecentResponseTimes";
static NSString * const kSLNLastExecutionTime = @"kSLNLastExecutionTime";

// Define the total available time for executing tasks on the background.
// Since every task has an associcated to it, this is critical to determine which tasks to execute.
// From Apple docs:
// "..your app has up to 30 seconds of wall-clock time to perform the download operation and call the specified completion handler block."
// https://developer.apple.com/library/ios/documentation/iphone/conceptual/iphoneosprogrammingguide/ManagingYourApplicationsFlow/ManagingYourApplicationsFlow.html
static CGFloat const kSLNAvailableTime = 30.0;

// Total number of response times to store for a given task.
// See http://en.wikipedia.org/wiki/Moving_average#Simple_moving_average
static NSInteger const kSLNDefaultNumberOfResponseTimesToInclude = 3;
static NSInteger const kSLNMinNumberOfResponseTimesToInclude = 0;
static NSInteger const kSLNMaxNumberOfResponseTimesToInclude = 30;

/******/

#pragma mark - SLNTaskContainer

// This is a convenience structure which wraps an id<SLNTaskProtocol>.
// It is only an internal class, used for keeping score, execution time, and facilitate sorting.
//
@interface SLNTaskContainer : NSObject

@property (nonatomic) CGFloat score;
@property (nonatomic, strong) id<SLNTaskProtocol> task;

// Store the last time the task was executed
@property (nonatomic) NSTimeInterval lastExecutionTime;

// Store the last N response times
@property (nonatomic, strong) NSMutableArray *recentReponseTimes;

@end

/******/

@implementation SLNTaskContainer

// Returns the elapsed time between now and its last execution
- (NSTimeInterval)elapsedTimeSinceLastExecution {
  return [[NSDate date] timeIntervalSince1970] - self.lastExecutionTime;
}

// Returns its id<SLNTaskProtocol> identifier
- (NSString *)key {
  return [self.task identifier];
}

- (void)addResponseTime:(CGFloat)responseTime {
  [self.recentReponseTimes addObject:@(responseTime)];

  NSInteger numberOfReponseTimesToInclude = kSLNDefaultNumberOfResponseTimesToInclude;

  if ([[self task] respondsToSelector:@selector(numberOfPeriodsForResponseTime)]) {
    numberOfReponseTimesToInclude = [self.task numberOfPeriodsForResponseTime];
    if (numberOfReponseTimesToInclude < kSLNMinNumberOfResponseTimesToInclude) {
      numberOfReponseTimesToInclude = kSLNMinNumberOfResponseTimesToInclude;
    } else if (numberOfReponseTimesToInclude > kSLNMaxNumberOfResponseTimesToInclude) {
      numberOfReponseTimesToInclude = kSLNMaxNumberOfResponseTimesToInclude;
    }
  }

  if ([self.recentReponseTimes count] > numberOfReponseTimesToInclude) {
    [self.recentReponseTimes removeObjectAtIndex:0];
  }
}

// Calculate a simple moving average of the last kSLNNumberOfReponseTimesToInclude.
// This gives us a more useful masurement when deciding to schedule the task.
// http://en.wikipedia.org/wiki/Moving_average#Simple_moving_average
//
- (CGFloat)movingAverageResponseTime {
  if ([self.recentReponseTimes count] == 0) {
    return [self.task averageResponseTime];
  }
  CGFloat totalResponseTime = 0;
  for (NSNumber *responseTime in self.recentReponseTimes) {
    totalResponseTime += [responseTime floatValue];
  }
  return totalResponseTime / [self.recentReponseTimes count];
}

// Deserialization into the current instance, with value of the NSDictionary from NSUserDefaults
- (void)updateWithDictionary:(NSDictionary *)dict {
  if (dict) {
    NSArray *recentReponseTimes = [dict objectForKey:kSLNRecentResponseTimes];
    NSInteger lastExecutionTime = [[dict objectForKey:kSLNLastExecutionTime] intValue];
    self.recentReponseTimes = [recentReponseTimes mutableCopy];
    self.lastExecutionTime = lastExecutionTime;
  } else {
    self.lastExecutionTime =  [[NSDate date] timeIntervalSince1970];
    self.recentReponseTimes = [NSMutableArray new];
  }
}

// Serialization into dictionary for quick persistence into NSUserDefaults
- (NSDictionary *)toDictionary {
  return @{
           kSLNRecentResponseTimes: [NSArray arrayWithArray:self.recentReponseTimes],
           kSLNLastExecutionTime: @(self.lastExecutionTime)
           };
}

- (NSString *)description {
  return [NSString stringWithFormat:@"task: %@, last execution time: %f, moving average response time: %f, last score: %f", [self key], self.lastExecutionTime, [self movingAverageResponseTime], self.score];
}

@end

/******/

#pragma mark - SLNScheduler

@interface SLNScheduler ()

// This is NSOpertionQueue which contains the list of NSOperations for every taks.  The NSOperations
// in this queue are marked for execution
@property (nonatomic, strong) NSOperationQueue *operationQueue;

// Stores the list of all SLNTaskContainers that should be checked for execution.
@property (nonatomic, strong) NSArray *taskContainers;

// Holds the entire list of background operations which need to execute
@property (nonatomic) dispatch_queue_t queue;

@property (nonatomic) NSTimeInterval minimumBackgroundFetchInterval;

@property (nonatomic, getter=isExecuting) BOOL executing;

@property (nonatomic, copy) void (^completion)(UIBackgroundFetchResult);

@end

@implementation SLNScheduler

#pragma mark - Normalization & Score

// Returns a normalized value
// http://en.wikipedia.org/wiki/Normalization_(statistics)
//
static inline double Normalize(double value, double min, double max) {
  return ((value - min)/(max == min ? 1 : (max - min)));
};

// Calculates the score based on priority and last execution time.
// Currently, this is a pretty rudimentary operation: (normalized priority) * (normalized last execution time)
//
static inline double Score(SLNTaskPriority priority, NSTimeInterval time, NSTimeInterval minTime, NSTimeInterval maxTime) {
  return Normalize(priority, 0, SLNTaskPriorityVeryHigh) * Normalize(time, minTime, maxTime);
};

#pragma mark - Instance

+ (instancetype)sharedInstance {
  static dispatch_once_t once;
  static SLNScheduler *instance;
  dispatch_once(&once, ^{
    instance = [self new];
    instance.operationQueue = [NSOperationQueue new];
    [instance.operationQueue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];
    instance.queue = dispatch_queue_create("selene.scheduler.queue", DISPATCH_QUEUE_SERIAL);
  });
  return instance;
}

#pragma mark - Accessors

+ (void)setMinimumBackgroundFetchInterval:(NSTimeInterval)minimumBackgroundFetchInterval {
  SLNScheduler *instance = [SLNScheduler sharedInstance];
  instance.minimumBackgroundFetchInterval = minimumBackgroundFetchInterval;
  [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:minimumBackgroundFetchInterval];
}

+ (void)setMaxConcurrentOperationCount:(NSInteger)maxConcurrentOperationCount {
  SLNScheduler *instance = [SLNScheduler sharedInstance];
  [instance.operationQueue setMaxConcurrentOperationCount:maxConcurrentOperationCount];
}

#pragma mark - Scheduling/Execution

+ (void)scheduleTasks:(NSArray *)tasks {
  SLNScheduler *instance = [SLNScheduler sharedInstance];
  
  // Retrieve the execution schedule from the user defaults.  Then:
  // 1) Create the task
  // 2) Iterate through the list of passed in scheduled tasks, and deserialize its content into the appropriate
  //    SLNTaskContainer
  NSDictionary *executionSchedule = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kSLNExecutionSchedule];

  // This flag dictates where the execution schedule should be saved.  This may occur when:
  // 1) The first time this code runs, thus there would be no execution schedule present
  // 2) When new tasks are inserted, thus they do not exist in the execution schedule.
  __block BOOL hasChanges = NO;

  NSMutableArray *taskContainers = [NSMutableArray new];

  [tasks enumerateObjectsUsingBlock:^(id<SLNTaskProtocol> task, NSUInteger idx, BOOL *stop) {
    NSAssert(([task priority] >= SLNTaskPriorityVeryLow) && [task priority] <= SLNTaskPriorityVeryHigh, @"Priority must be between [SLNTaskPriorityVeryLow,SLNTaskPriorityVeryHigh]");
    NSAssert(([task averageResponseTime] >= 0) && [task averageResponseTime] <= kSLNAvailableTime, @"averageResponseTime must be in the range of [0,30]");

    SLNTaskContainer *t = [SLNTaskContainer new];
    t.task = task;

    NSDictionary *schedule = [executionSchedule objectForKey:[t key]];

    [t updateWithDictionary:schedule];

    if (!schedule) {
      hasChanges = YES;
    }

    [taskContainers addObject:t];
  }];

  instance.taskContainers = taskContainers;

  if (hasChanges) {
    [instance save];
  }
}

+ (void)scheduleNow:(id<SLNTaskProtocol>)task {
  // Purposely left blank. We'll implement this at a later date.  For now this isn't needed,
  // but is left here as a reminder of good things to come.
}

+ (void)startWithCompletion:(void (^)(UIBackgroundFetchResult))completion {
  NSAssert(completion != nil, @"Completion block must exist.");
  
  SLNScheduler *instance = [SLNScheduler sharedInstance];
  if (instance.isExecuting) {
    SLNLog(@"Scheduler already running.");
    return;
  }

  instance.executing = YES;
  instance.completion = [completion copy];

  // Retrieve the taks that need to execute
  NSArray *tasks = [instance nextTasks];

  // If there are no operations, then there's nothing to do.  Simply short-cicuit.
  if ([tasks count] == 0) {
    dispatch_async(dispatch_get_main_queue(), ^{
      instance.executing = NO;
      instance.completion(UIBackgroundFetchResultNoData);
    });
    return;
  }

  dispatch_async(instance.queue, ^{
    [instance execute:tasks];
  });
}

+ (void)stop {
  [self setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalNever];
}

+ (void)reset {
  SLNScheduler *instance = [SLNScheduler sharedInstance];

  dispatch_async(instance.queue, ^{
    if ([instance.operationQueue operationCount] > 0) {
      [instance.operationQueue waitUntilAllOperationsAreFinished];
    }
    instance.taskContainers = nil;
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults removeObjectForKey:kSLNExecutionSchedule];
    [userDefaults synchronize];
  });
}

#pragma mark - Instance: Execution

// Executes the list of items.  When the execution of *all* tasks is complete, the completion
// block is invoked.
- (void)execute:(NSArray *)taskItems {
  __weak __typeof(self) weakSelf = self;

  __block UIBackgroundFetchResult finalResult = UIBackgroundFetchResultNoData;

  // Operation which depends on all the other operations. This will serve as a final "completion" trigger
  NSOperation *finalOp = [NSOperation new];

  // Iterate through the list of scheduled operations, and for each one, add its NSOperation
  // to the queue.  Additionally, set a completion block responsible for updating the last sync time
  // of this scheduled operation

  NSDate *start = [NSDate date];

  [taskItems enumerateObjectsUsingBlock:^(SLNTaskContainer *t, NSUInteger idx, BOOL *stop) {
    NSOperation *operation = [t.task operationWithCompletion:^(UIBackgroundFetchResult result) {
      if (result == UIBackgroundFetchResultNewData) {
        finalResult = UIBackgroundFetchResultNewData;
      }
      NSDate *finish = [NSDate date];
      t.lastExecutionTime = [finish timeIntervalSince1970];
      NSTimeInterval interval = [finish timeIntervalSinceDate:start];
      [t addResponseTime:interval];
    }];

    [finalOp addDependency:operation];
    [weakSelf.operationQueue addOperation:operation];
  }];

  [finalOp setCompletionBlock:^{
    // Update the execution schedule
    [weakSelf save];
    // And we're done!
    if (weakSelf.completion) {
      dispatch_async(dispatch_get_main_queue(), ^{
        weakSelf.executing = NO;
        weakSelf.completion(finalResult);
      });
    }
  }];

  [self.operationQueue addOperation:finalOp];
}

// Returns a list of SLNTaskContainer(s) which need to execute.
// Note that this may be a subset of all task items.
//
// The logic is as follows:
//
// 1) For every task:
//     a) Retrieve the last execution time, and its priority.
//     b) Calculate the score
// 2) Sort the tasks by their score
// 3) Since every task has an average response time, we can determine which
//    tasks to run by using the total available response time.
//
// Example:
//
// Suppose...
// - we've calculated the scores of tasks x,y,z to be S(x) = 3, S(y) = 2, S(z) = 1
// - the average response times are T(x) = 20, T(y) = 5, T(z) = 10
// - the available time is 30s
//
// Therfore, the execution list, sorted by their score would be [x,y,z].
// Since the available response time is 30, only x,y can be executed, since T(x) + T(y) <= 30.
//
// Note that since the score is a function of a background task's priority and last execution time, it is
// guaranteed that unexecuted tasks will still execute at subsequent points in time, when their score
// is higher in the list.
//
- (NSArray *)nextTasks {
  CGFloat minElapsedTimeSinceLastExecution = 0;
  __block CGFloat maxElapsedTimeSinceLastExecution = 0;

  // Calculate the max elapsed time
  [self.taskContainers enumerateObjectsUsingBlock:^(SLNTaskContainer *t, NSUInteger idx, BOOL *stop) {
    maxElapsedTimeSinceLastExecution = MAX([t elapsedTimeSinceLastExecution], maxElapsedTimeSinceLastExecution);
  }];

  // Calculate the score for every task
  [self.taskContainers enumerateObjectsUsingBlock:^(SLNTaskContainer *t, NSUInteger idx, BOOL *stop) {
    t.score = Score([t.task priority], [t elapsedTimeSinceLastExecution], minElapsedTimeSinceLastExecution, maxElapsedTimeSinceLastExecution);
  }];

  // Sort the tasks by score
  NSArray *sortedTasksByScore = [self.taskContainers sortedArrayUsingComparator:^NSComparisonResult(SLNTaskContainer *obj1, SLNTaskContainer *obj2) {
    if (obj1.score > obj2.score) {
      return NSOrderedAscending;
    } else if (obj1.score < obj2.score) {
      return NSOrderedDescending;
    } else {
      return NSOrderedDescending;
    }
  }];

  // Determine which tasks to run, by looking at their cost
  NSMutableArray *scheduledTasks = [[NSMutableArray alloc] init];
  __block CGFloat totalResponseTime = 0.0;

  [sortedTasksByScore enumerateObjectsUsingBlock:^(SLNTaskContainer *t, NSUInteger idx, BOOL *stop) {
    CGFloat average = [t movingAverageResponseTime];
    if (totalResponseTime + average <= kSLNAvailableTime) {
      totalResponseTime += average;
      [scheduledTasks addObject:t];
    }
  }];

  return scheduledTasks;
}

- (void)save {
  NSMutableDictionary *nextExecutionSchedule = [NSMutableDictionary new];
  [self.taskContainers enumerateObjectsUsingBlock:^(SLNTaskContainer *t, NSUInteger idx, BOOL *stop) {
    nextExecutionSchedule[[t key]] = [t toDictionary];
  }];
  NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
  [userDefaults setObject:[NSDictionary dictionaryWithDictionary:nextExecutionSchedule] forKey:kSLNExecutionSchedule];
  [userDefaults synchronize];
}

@end