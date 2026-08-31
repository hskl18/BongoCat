#import "BongoCubism.h"

#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <memory>

#include <CubismFramework.hpp>
#include <Effect/CubismPose.hpp>
#include <Id/CubismIdManager.hpp>
#include <Math/CubismMatrix44.hpp>
#include <Model/CubismUserModel.hpp>
#include <Motion/CubismMotion.hpp>
#include <Physics/CubismPhysics.hpp>
#include <Rendering/Metal/CubismDeviceInfo_Metal.hpp>
#include <Rendering/Metal/CubismRenderer_Metal.hpp>

using namespace Live2D::Cubism::Framework;
using namespace Live2D::Cubism::Framework::Rendering;

namespace {

NSString *const BCErrorDomain = @"com.local.BongoCat.Cubism";

class BCAllocator final : public ICubismAllocator {
public:
    void *Allocate(const csmSizeType size) override {
        return std::malloc(size);
    }

    void Deallocate(void *memory) override {
        std::free(memory);
    }

    void *AllocateAligned(const csmSizeType size, const csmUint32 alignment) override {
        void *memory = nullptr;
        return posix_memalign(&memory, alignment, size) == 0 ? memory : nullptr;
    }

    void DeallocateAligned(void *alignedMemory) override {
        std::free(alignedMemory);
    }
};

BCAllocator allocator;

void InitializeCubism() {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CubismFramework::Option option;
        option.LoggingLevel = CubismFramework::Option::LogLevel_Off;
        CubismFramework::StartUp(&allocator, &option);
        CubismFramework::Initialize();
    });
}

NSError *BCError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:BCErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

NSURL *ResolveModelFile(NSURL *directory, NSString *relativePath, NSError **error) {
    if (![relativePath isKindOfClass:NSString.class] ||
        relativePath.length == 0 ||
        [relativePath hasPrefix:@"/"]) {
        if (error) *error = BCError(8, @"A model file reference is invalid.");
        return nil;
    }

    NSURL *root = [[directory URLByStandardizingPath] URLByResolvingSymlinksInPath];
    NSURL *candidate = [[[directory URLByAppendingPathComponent:relativePath]
        URLByStandardizingPath] URLByResolvingSymlinksInPath];
    NSString *rootPrefix = [root.path stringByAppendingString:@"/"];
    if (![candidate.path hasPrefix:rootPrefix] ||
        ![[NSFileManager defaultManager] fileExistsAtPath:candidate.path]) {
        if (error) {
            *error = BCError(
                9,
                [NSString stringWithFormat:@"A model file is missing or outside its directory: %@", relativePath]
            );
        }
        return nil;
    }
    return candidate;
}

NSData *ReadModelFile(NSURL *directory, NSString *relativePath, NSError **error) {
    NSURL *url = ResolveModelFile(directory, relativePath, error);
    return url ? [NSData dataWithContentsOfURL:url options:0 error:error] : nil;
}

double ClampRatio(double value) {
    return std::min(std::max(value, 0.0), 1.0);
}

class BCModel final : public CubismUserModel {
public:
    bool Load(NSURL *directory, id<MTLDevice> device, bool createRenderer, NSError **error) {
        NSURL *settingURL = nil;
        NSArray<NSURL *> *items = [[NSFileManager defaultManager]
            contentsOfDirectoryAtURL:directory
            includingPropertiesForKeys:nil
            options:NSDirectoryEnumerationSkipsHiddenFiles
            error:error];
        if (!items) {
            return false;
        }

        for (NSURL *item in items) {
            if ([item.pathExtension.lowercaseString isEqualToString:@"json"] &&
                [item.lastPathComponent hasSuffix:@".model3.json"]) {
                settingURL = item;
                break;
            }
        }
        if (!settingURL) {
            if (error) *error = BCError(1, @"No .model3.json file was found.");
            return false;
        }

        NSData *settingData = [NSData dataWithContentsOfURL:settingURL options:0 error:error];
        if (!settingData) {
            return false;
        }
        NSDictionary *setting = [NSJSONSerialization JSONObjectWithData:settingData options:0 error:error];
        NSDictionary *references = [setting isKindOfClass:NSDictionary.class]
            ? setting[@"FileReferences"]
            : nil;
        NSString *mocName = [references isKindOfClass:NSDictionary.class]
            ? references[@"Moc"]
            : nil;
        NSArray<NSString *> *textureNames = [references isKindOfClass:NSDictionary.class]
            ? references[@"Textures"]
            : nil;
        if (![mocName isKindOfClass:NSString.class] ||
            ![textureNames isKindOfClass:NSArray.class]) {
            if (error) *error = BCError(2, @"The model settings are missing Moc or Textures.");
            return false;
        }

        NSData *mocData = ReadModelFile(directory, mocName, error);
        if (!mocData) {
            return false;
        }
        LoadModel(static_cast<const csmByte *>(mocData.bytes), mocData.length, true);
        if (!GetModel()) {
            if (error) *error = BCError(3, @"Cubism Core rejected the .moc3 model.");
            return false;
        }

        id physicsValue = references[@"Physics"];
        if (physicsValue && ![physicsValue isKindOfClass:NSString.class]) {
            if (error) *error = BCError(11, @"The Physics reference is invalid.");
            return false;
        }
        if ([physicsValue isKindOfClass:NSString.class] && [physicsValue length] > 0) {
            NSData *physicsData = ReadModelFile(directory, physicsValue, error);
            if (!physicsData) return false;
            LoadPhysics(static_cast<const csmByte *>(physicsData.bytes), physicsData.length);
            if (!_physics) {
                if (error) *error = BCError(12, @"Cubism rejected the physics file.");
                return false;
            }
        }

        id poseValue = references[@"Pose"];
        if (poseValue && ![poseValue isKindOfClass:NSString.class]) {
            if (error) *error = BCError(13, @"The Pose reference is invalid.");
            return false;
        }
        if ([poseValue isKindOfClass:NSString.class] && [poseValue length] > 0) {
            NSData *poseData = ReadModelFile(directory, poseValue, error);
            if (!poseData) return false;
            LoadPose(static_cast<const csmByte *>(poseData.bytes), poseData.length);
            if (!_pose) {
                if (error) *error = BCError(14, @"Cubism rejected the pose file.");
                return false;
            }
        }

        if (!createRenderer) {
            return true;
        }

        CreateRenderer(1, 1);
        auto *renderer = GetRenderer<CubismRenderer_Metal>();
        if (!renderer) {
            if (error) *error = BCError(4, @"The Cubism Metal renderer was not created.");
            return false;
        }

        MTKTextureLoader *loader = [[MTKTextureLoader alloc] initWithDevice:device];
        NSMutableArray<id<MTLTexture>> *loadedTextures = [NSMutableArray array];
        NSDictionary<MTKTextureLoaderOption, id> *options = @{
            MTKTextureLoaderOptionSRGB: @NO,
            MTKTextureLoaderOptionOrigin: MTKTextureLoaderOriginTopLeft,
            MTKTextureLoaderOptionGenerateMipmaps: @YES,
        };
        for (NSUInteger index = 0; index < textureNames.count; index++) {
            NSString *name = textureNames[index];
            if (![name isKindOfClass:NSString.class]) {
                if (error) *error = BCError(5, @"A model texture path is invalid.");
                return false;
            }
            NSURL *textureURL = ResolveModelFile(directory, name, error);
            if (!textureURL) return false;
            id<MTLTexture> texture = [loader
                newTextureWithContentsOfURL:textureURL
                options:options
                error:error];
            if (!texture) {
                return false;
            }
            [loadedTextures addObject:texture];
            renderer->BindTexture(static_cast<csmUint32>(index), texture);
        }
        renderer->IsPremultipliedAlpha(false);
        textures_ = loadedTextures;
        return true;
    }

    void ApplyPointer(double xRatio, double yRatio, bool mirrored) {
        SetRatioParameter("ParamMouseX", xRatio, mirrored);
        SetRatioParameter("ParamMouseY", yRatio, false);
        SetRatioParameter("ParamAngleX", xRatio, mirrored);
        SetRatioParameter("ParamAngleY", yRatio, false);
        SetRatioParameter("ParamEyeBallX", xRatio, mirrored);
        SetRatioParameter("ParamEyeBallY", yRatio, false);

        const double dragX = 1.0 - 2.0 * xRatio;
        const double dragY = 1.0 - 2.0 * yRatio;
        const csmInt32 index = ParameterIndex("ParamAngleZ");
        if (index >= 0) {
            double value = dragX * dragY * GetModel()->GetParameterMinimumValue(index);
            if (mirrored) value *= -1.0;
            GetModel()->SetParameterValue(index, static_cast<csmFloat32>(value));
        }
    }

    void SetBooleanParameter(const char *name, bool value) {
        const csmInt32 index = ParameterIndex(name);
        if (index >= 0) {
            GetModel()->SetParameterValue(index, value ? 1.0f : 0.0f);
        }
    }

    void SetNumberParameter(const char *name, double value) {
        const csmInt32 index = ParameterIndex(name);
        if (index >= 0) {
            GetModel()->SetParameterValue(index, static_cast<csmFloat32>(value));
        }
    }

    bool StartMotion(NSURL *motionFileURL, NSError **error) {
        NSData *data = [NSData dataWithContentsOfURL:motionFileURL options:0 error:error];
        if (!data) return false;
        ACubismMotion *motion = LoadMotion(
            static_cast<const csmByte *>(data.bytes),
            data.length,
            nullptr,
            nullptr,
            nullptr
        );
        if (!motion) {
            if (error) *error = BCError(20, @"Cubism rejected the motion file.");
            return false;
        }
        _motionManager->StopAllMotions();
        return _motionManager->StartMotionPriority(motion, true, 3)
            != InvalidMotionQueueEntryHandleValue;
    }

    bool SetExpression(NSURL *expressionFileURL, NSError **error) {
        NSData *data = [NSData dataWithContentsOfURL:expressionFileURL options:0 error:error];
        if (!data) return false;
        ACubismMotion *expression = LoadExpression(
            static_cast<const csmByte *>(data.bytes),
            data.length,
            nullptr
        );
        if (!expression) {
            if (error) *error = BCError(21, @"Cubism rejected the expression file.");
            return false;
        }
        _expressionManager->StartMotion(expression, true);
        return true;
    }

    void UpdateAnimations(double deltaTimeSeconds) {
        if (!_motionManager->IsFinished()) {
            GetModel()->LoadParameters();
            _motionManager->UpdateMotion(
                GetModel(),
                static_cast<csmFloat32>(deltaTimeSeconds)
            );
            GetModel()->SaveParameters();
        }
        if (!_expressionManager->IsFinished()) {
            _expressionManager->UpdateMotion(
                GetModel(),
                static_cast<csmFloat32>(deltaTimeSeconds)
            );
        }
    }

    void UpdateDynamics(double deltaTimeSeconds) {
        if (_physics) {
            _physics->Evaluate(GetModel(), static_cast<csmFloat32>(deltaTimeSeconds));
        }
        if (_pose) {
            _pose->UpdateParameters(GetModel(), static_cast<csmFloat32>(deltaTimeSeconds));
        }
    }

    bool HasActiveAnimations() const {
        return !_motionManager->IsFinished() || !_expressionManager->IsFinished();
    }

    bool HasDynamicSimulation() const {
        return _physics != nullptr || _pose != nullptr;
    }

    bool ValidateParameterChange(NSString *parameterID,
                                 double fromValue,
                                 double toValue,
                                 NSError **error) {
        const csmInt32 index = ParameterIndex(parameterID.UTF8String);
        if (index < 0) {
            if (error) {
                *error = BCError(6, [NSString stringWithFormat:@"The model has no %@ parameter.", parameterID]);
            }
            return false;
        }

        GetModel()->SetParameterValue(index, static_cast<csmFloat32>(fromValue));
        GetModel()->Update();
        const std::uint64_t before = DrawableDigest();

        GetModel()->SetParameterValue(index, static_cast<csmFloat32>(toValue));
        GetModel()->Update();
        const std::uint64_t after = DrawableDigest();

        if (before == after) {
            if (error) {
                *error = BCError(7, [NSString stringWithFormat:@"%@ does not change evaluated drawables.", parameterID]);
            }
            return false;
        }
        return true;
    }

    void UpdateAndDraw(id<MTLCommandBuffer> commandBuffer,
                       MTLRenderPassDescriptor *descriptor,
                       CGSize drawableSize) {
        if (!GetModel() || drawableSize.width <= 0 || drawableSize.height <= 0) {
            return;
        }

        auto *renderer = GetRenderer<CubismRenderer_Metal>();
        renderer->StartFrame(commandBuffer, descriptor);
        renderer->SetRenderViewport(MTLViewport{
            0.0, 0.0,
            static_cast<double>(drawableSize.width),
            static_cast<double>(drawableSize.height),
            0.0, 1.0,
        });

        CubismMatrix44 projection;
        const float aspectRatio = static_cast<float>(drawableSize.width / drawableSize.height);
        const float displayRatio = static_cast<float>(drawableSize.height / drawableSize.width);
        const float canvasRatio = GetModel()->GetCanvasHeight() / GetModel()->GetCanvasWidth();
        if (canvasRatio < displayRatio) {
            GetModelMatrix()->SetWidth(2.0f);
            projection.Scale(1.0f, aspectRatio);
        } else {
            GetModelMatrix()->SetHeight(2.0f);
            projection.Scale(1.0f / aspectRatio, 1.0f);
        }
        projection.MultiplyByMatrix(GetModelMatrix());
        renderer->SetMvpMatrix(&projection);
        GetModel()->Update();
        renderer->DrawModel();
    }

private:
    std::uint64_t DrawableDigest() {
        std::uint64_t hash = 1469598103934665603ULL;
        auto mix = [&hash](const void *bytes, std::size_t length) {
            const auto *values = static_cast<const std::uint8_t *>(bytes);
            for (std::size_t index = 0; index < length; ++index) {
                hash ^= values[index];
                hash *= 1099511628211ULL;
            }
        };

        const csmInt32 count = GetModel()->GetDrawableCount();
        for (csmInt32 drawable = 0; drawable < count; ++drawable) {
            const csmFloat32 opacity = GetModel()->GetDrawableOpacity(drawable);
            const Live2D::Cubism::Core::csmVector4 multiply = GetModel()->GetDrawableMultiplyColor(drawable);
            const Live2D::Cubism::Core::csmVector4 screen = GetModel()->GetDrawableScreenColor(drawable);
            const csmInt32 vertexCount = GetModel()->GetDrawableVertexCount(drawable);
            mix(&opacity, sizeof(opacity));
            mix(&multiply, sizeof(multiply));
            mix(&screen, sizeof(screen));
            mix(GetModel()->GetDrawableVertexPositions(drawable),
                sizeof(Live2D::Cubism::Core::csmVector2) * static_cast<std::size_t>(vertexCount));
        }
        return hash;
    }

    csmInt32 ParameterIndex(const char *name) {
        if (!GetModel()) return -1;
        auto id = CubismFramework::GetIdManager()->GetId(name);
        const csmInt32 index = GetModel()->GetParameterIndex(id);
        return index < GetModel()->GetParameterCount() ? index : -1;
    }

    void SetRatioParameter(const char *name, double ratio, bool mirrored) {
        const csmInt32 index = ParameterIndex(name);
        if (index < 0) return;
        const double minimum = GetModel()->GetParameterMinimumValue(index);
        const double maximum = GetModel()->GetParameterMaximumValue(index);
        double value = maximum - ClampRatio(ratio) * (maximum - minimum);
        if (mirrored) value *= -1.0;
        GetModel()->SetParameterValue(index, static_cast<csmFloat32>(value));
    }

    __strong NSArray<id<MTLTexture>> *textures_;
};

} // namespace

@interface BCCubismView () <MTKViewDelegate>
@end

@implementation BCCubismView {
    std::unique_ptr<BCModel> _model;
    id<MTLCommandQueue> _commandQueue;
    NSURL *_modelDirectory;
    double _pointerXRatio;
    double _pointerYRatio;
    BOOL _pointerMirrored;
    BOOL _leftMouseDown;
    BOOL _rightMouseDown;
    BOOL _leftHandDown;
    BOOL _rightHandDown;
    NSDictionary<NSString *, NSNumber *> *_parameterValues;
    CFTimeInterval _lastFrameTime;
    CFTimeInterval _renderUntilTime;
}

+ (BOOL)validateModelDirectory:(NSURL *)modelDirectory error:(NSError **)error {
    InitializeCubism();
    BCModel model;
    return model.Load(modelDirectory, nil, false, error);
}

+ (BOOL)validateModelDirectory:(NSURL *)modelDirectory
         parameterChangesModel:(NSString *)parameterID
                     fromValue:(double)fromValue
                       toValue:(double)toValue
                         error:(NSError **)error {
    InitializeCubism();
    BCModel model;
    if (!model.Load(modelDirectory, nil, false, error)) {
        return NO;
    }
    return model.ValidateParameterChange(parameterID, fromValue, toValue, error);
}

+ (BOOL)validateModelDirectory:(NSURL *)modelDirectory
                 motionFileURL:(NSURL *)motionFileURL
             expressionFileURL:(NSURL *)expressionFileURL
                         error:(NSError **)error {
    InitializeCubism();
    BCModel model;
    if (!model.Load(modelDirectory, nil, false, error)) {
        return NO;
    }
    return model.StartMotion(motionFileURL, error)
        && model.SetExpression(expressionFileURL, error);
}

- (instancetype)initWithFrame:(NSRect)frameRect
                modelDirectory:(NSURL *)modelDirectory
                         error:(NSError **)error {
    InitializeCubism();
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
        if (error) *error = BCError(10, @"Metal is unavailable on this Mac.");
        return nil;
    }

    self = [super initWithFrame:frameRect device:device];
    if (!self) return nil;

    self.delegate = self;
    self.paused = YES;
    self.enableSetNeedsDisplay = YES;
    self.preferredFramesPerSecond = 60;
    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
    self.framebufferOnly = YES;
    self.layer.opaque = NO;
    _commandQueue = [device newCommandQueue];
    _pointerXRatio = 0.5;
    _pointerYRatio = 0.5;
    _parameterValues = @{};
    _lastFrameTime = CACurrentMediaTime();
    _renderUntilTime = _lastFrameTime;

    CubismRenderer_Metal::SetConstantSettings(device);
    if (![self loadModelDirectory:modelDirectory error:error]) {
        return nil;
    }
    return self;
}

- (BOOL)loadModelDirectory:(NSURL *)modelDirectory error:(NSError **)error {
    if ([_modelDirectory isEqual:modelDirectory] && _model) {
        return YES;
    }
    std::unique_ptr<BCModel> candidate = std::make_unique<BCModel>();
    if (!candidate->Load(modelDirectory, self.device, true, error)) {
        return NO;
    }
    _modelDirectory = modelDirectory;
    _model = std::move(candidate);
    _lastFrameTime = CACurrentMediaTime();
    _renderUntilTime = _lastFrameTime + (_model->HasDynamicSimulation() ? 0.75 : 0.0);
    self.paused = !_model->HasDynamicSimulation();
    [self setNeedsDisplay:YES];
    return YES;
}

- (void)setPointerXRatio:(double)xRatio yRatio:(double)yRatio mirrored:(BOOL)mirrored {
    const double nextX = ClampRatio(xRatio);
    const double nextY = ClampRatio(yRatio);
    if (_pointerXRatio == nextX && _pointerYRatio == nextY && _pointerMirrored == mirrored) {
        return;
    }
    _pointerXRatio = nextX;
    _pointerYRatio = nextY;
    _pointerMirrored = mirrored;
    [self requestRender];
}

- (void)setLeftMouseDown:(BOOL)leftMouseDown
           rightMouseDown:(BOOL)rightMouseDown
            leftHandDown:(BOOL)leftHandDown
           rightHandDown:(BOOL)rightHandDown {
    if (_leftMouseDown == leftMouseDown &&
        _rightMouseDown == rightMouseDown &&
        _leftHandDown == leftHandDown &&
        _rightHandDown == rightHandDown) {
        return;
    }
    _leftMouseDown = leftMouseDown;
    _rightMouseDown = rightMouseDown;
    _leftHandDown = leftHandDown;
    _rightHandDown = rightHandDown;
    [self requestRender];
}

- (void)setParameterValues:(NSDictionary<NSString *, NSNumber *> *)parameterValues {
    if ([_parameterValues isEqualToDictionary:parameterValues]) {
        return;
    }
    _parameterValues = [parameterValues copy];
    [self requestRender];
}

- (BOOL)startMotionFileURL:(NSURL *)motionFileURL error:(NSError **)error {
    if (!_model || !_model->StartMotion(motionFileURL, error)) {
        return NO;
    }
    _lastFrameTime = CACurrentMediaTime();
    self.paused = NO;
    return YES;
}

- (BOOL)setExpressionFileURL:(NSURL *)expressionFileURL error:(NSError **)error {
    if (!_model || !_model->SetExpression(expressionFileURL, error)) {
        return NO;
    }
    _lastFrameTime = CACurrentMediaTime();
    self.paused = NO;
    return YES;
}

- (void)setMaximumFramesPerSecond:(NSInteger)maximumFramesPerSecond {
    self.preferredFramesPerSecond = static_cast<NSInteger>(
        std::min(std::max(maximumFramesPerSecond, 1L), 240L)
    );
}

- (void)requestRender {
    if (_model && _model->HasDynamicSimulation()) {
        _renderUntilTime = CACurrentMediaTime() + 0.75;
        self.paused = NO;
    }
    [self setNeedsDisplay:YES];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    [view setNeedsDisplay:YES];
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    if (!self.window) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setNeedsDisplay:YES];
    });
}

- (void)drawInMTKView:(MTKView *)view {
    if (!_model || !view.currentDrawable || !view.currentRenderPassDescriptor) {
        return;
    }

    const CFTimeInterval currentTime = CACurrentMediaTime();
    const double deltaTime = std::min(std::max(currentTime - _lastFrameTime, 0.0), 0.1);
    _lastFrameTime = currentTime;
    _model->UpdateAnimations(deltaTime);
    _model->ApplyPointer(_pointerXRatio, _pointerYRatio, _pointerMirrored);
    _model->SetBooleanParameter("ParamMouseLeftDown", _leftMouseDown);
    _model->SetBooleanParameter("ParamMouseRightDown", _rightMouseDown);
    _model->SetBooleanParameter("CatParamLeftHandDown", _leftHandDown);
    _model->SetBooleanParameter("CatParamRightHandDown", _rightHandDown);
    [_parameterValues enumerateKeysAndObjectsUsingBlock:^(NSString *parameterID, NSNumber *value, BOOL *) {
        _model->SetNumberParameter(parameterID.UTF8String, value.doubleValue);
    }];
    _model->UpdateDynamics(deltaTime);

    MTLRenderPassDescriptor *descriptor = view.currentRenderPassDescriptor;
    descriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    descriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    descriptor.colorAttachments[0].clearColor = self.clearColor;

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    CubismDeviceInfo_Metal::GetDeviceInfo(view.device)->GetOffscreenManager()->BeginFrameProcess();
    _model->UpdateAndDraw(commandBuffer, descriptor, view.drawableSize);
    CubismDeviceInfo_Metal::GetDeviceInfo(view.device)->GetOffscreenManager()->EndFrameProcess();
    CubismDeviceInfo_Metal::GetDeviceInfo(view.device)->GetOffscreenManager()->ReleaseStaleRenderTextures();
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
    if (_model->HasActiveAnimations()) {
        _renderUntilTime = currentTime + 0.75;
    } else if (currentTime >= _renderUntilTime) {
        view.paused = YES;
    }
}

@end
