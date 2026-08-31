#import <AppKit/AppKit.h>
#import <MetalKit/MetalKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BCCubismView : MTKView

+ (BOOL)validateModelDirectory:(NSURL *)modelDirectory
                         error:(NSError * _Nullable * _Nullable)error;

+ (BOOL)validateModelDirectory:(NSURL *)modelDirectory
         parameterChangesModel:(NSString *)parameterID
                     fromValue:(double)fromValue
                       toValue:(double)toValue
                         error:(NSError * _Nullable * _Nullable)error;

+ (BOOL)validateModelDirectory:(NSURL *)modelDirectory
                 motionFileURL:(NSURL *)motionFileURL
             expressionFileURL:(NSURL *)expressionFileURL
                         error:(NSError * _Nullable * _Nullable)error;

- (nullable instancetype)initWithFrame:(NSRect)frameRect
                         modelDirectory:(NSURL *)modelDirectory
                                   error:(NSError * _Nullable * _Nullable)error;

- (BOOL)loadModelDirectory:(NSURL *)modelDirectory
                      error:(NSError * _Nullable * _Nullable)error;

- (void)setPointerXRatio:(double)xRatio
                   yRatio:(double)yRatio
                 mirrored:(BOOL)mirrored;

- (void)setLeftMouseDown:(BOOL)leftMouseDown
           rightMouseDown:(BOOL)rightMouseDown
             leftHandDown:(BOOL)leftHandDown
            rightHandDown:(BOOL)rightHandDown;

- (void)setParameterValues:(NSDictionary<NSString *, NSNumber *> *)parameterValues;

- (BOOL)startMotionFileURL:(NSURL *)motionFileURL
                     error:(NSError * _Nullable * _Nullable)error;

- (BOOL)setExpressionFileURL:(NSURL *)expressionFileURL
                       error:(NSError * _Nullable * _Nullable)error;

- (void)setMaximumFramesPerSecond:(NSInteger)maximumFramesPerSecond;

@end

NS_ASSUME_NONNULL_END
