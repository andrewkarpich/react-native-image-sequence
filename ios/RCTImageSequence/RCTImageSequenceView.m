//
// Created by Mads Lee Jensen on 07/07/16.
// Copyright (c) 2016 Facebook. All rights reserved.
//

#import "RCTImageSequenceView.h"
#import "RCTComponent.h"

@interface RCTImageSequenceView ()

@property (nonatomic, copy) RCTBubblingEventBlock onAnimationStart;
@property (nonatomic, copy) RCTBubblingEventBlock onAnimationFinish;

@end

@implementation RCTImageSequenceView {
    NSUInteger _framesPerSecond;
    NSMutableDictionary *_activeTasks;
    NSMutableDictionary *_imagesLoaded;
    BOOL _loop;
}

- (void)setImages:(NSArray *)images {
    __weak RCTImageSequenceView *weakSelf = self;

    self.contentMode = UIViewContentModeScaleAspectFill;
    self.animationImages = nil;

    _activeTasks = [NSMutableDictionary new];
    _imagesLoaded = [NSMutableDictionary new];

    for (NSUInteger index = 0; index < images.count; index++) {
        NSDictionary *item = images[index];

        #ifdef DEBUG
        NSString *url = item[@"uri"];
        #else
        NSString *url = [NSString stringWithFormat:@"file://%@", item[@"uri"]]; // when not in debug, the paths are "local paths" (because resources are bundled in app)
        #endif

        dispatch_async(dispatch_queue_create("dk.mads-lee.ImageSequence.Downloader", NULL), ^{
            UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:url]]];
            dispatch_async(dispatch_get_main_queue(), ^{
              [weakSelf onImageLoadTaskAtIndex:index image:image];
            });
        });

        _activeTasks[@(index)] = url;
    }
}

- (void)onImageLoadTaskAtIndex:(NSUInteger)index image:(UIImage *)image {
    if (index == 0) {
        self.image = image;
    }

    [_activeTasks removeObjectForKey:@(index)];

    _imagesLoaded[@(index)] = image;

    if (_activeTasks.allValues.count == 0) {
        [self onImagesLoaded];
    }
}

- (void)onImagesLoaded {
    NSMutableArray *images = [NSMutableArray new];
    for (NSUInteger index = 0; index < _imagesLoaded.allValues.count; index++) {
        UIImage *image = _imagesLoaded[@(index)];
        [images addObject:image];
    }

    [_imagesLoaded removeAllObjects];

    self.image = nil;
    self.animationDuration = images.count * (1.0f / _framesPerSecond);
    self.animationImages = images;
    self.animationRepeatCount = _loop ? 0 : 1;
    [self startAnimating];
    RCTBubblingEventBlock onStart = _onAnimationStart;
    if (onStart) {
        onStart(@{});
    }
    if (!_loop) {
        dispatch_time_t finishTime = dispatch_time(DISPATCH_TIME_NOW,
                                                   self.animationDuration * self.animationRepeatCount * NSEC_PER_SEC);
        dispatch_after(finishTime, dispatch_get_main_queue(), ^{
            RCTBubblingEventBlock onFinish = self.onAnimationFinish;
            if (onFinish) {
                onFinish(@{});
            }
        });
    }
}

- (void)setFramesPerSecond:(NSUInteger)framesPerSecond {
    _framesPerSecond = framesPerSecond;

    if (self.animationImages.count > 0) {
        self.animationDuration = self.animationImages.count * (1.0f / _framesPerSecond);
    }
}

- (void)setLoop:(NSUInteger)loop {
    _loop = loop;

    self.animationRepeatCount = _loop ? 0 : 1;
}

@end
