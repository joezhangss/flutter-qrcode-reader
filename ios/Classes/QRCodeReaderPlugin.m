#import "QRCodeReaderPlugin.h"

static NSString *const CHANNEL_NAME = @"qrcode_reader";
static FlutterMethodChannel *channel;

@interface QRCodeReaderPlugin()<AVCaptureMetadataOutputObjectsDelegate>
@property (nonatomic, strong) UIView *viewPreview;
@property (nonatomic, strong) UIView *qrcodeview;
@property (nonatomic, strong) UIButton *buttonCancel;
@property (nonatomic) BOOL isReading;
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;
-(BOOL)startReading;
-(void)stopReading;
@property (nonatomic, retain) UIViewController *viewController;
@property (nonatomic, retain) UIViewController *qrcodeViewController;
@property (nonatomic) BOOL isFrontCamera;
//zq modify start
@property(retain,nonatomic) NSTimer* nsTime;
@property (nonatomic, strong) UIView *scanLineView;
//zq modify end
@end

@implementation QRCodeReaderPlugin {
FlutterResult _result;
UIViewController *_viewController;
}

float height;
float width;
float landscapeheight;
float portraitheight;

//zq modify start
float borderWidth ;
float borderHeight ;
float borderX;
float borderY;
//zq modify end

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel 
                                     methodChannelWithName:CHANNEL_NAME 
                                     binaryMessenger:[registrar messenger]];
    UIViewController *viewController =
    [UIApplication sharedApplication].delegate.window.rootViewController;
    QRCodeReaderPlugin* instance = [[QRCodeReaderPlugin alloc] initWithViewController:viewController];
    [registrar addMethodCallDelegate:instance channel:channel];
}


- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSDictionary *args = (NSDictionary *)call.arguments;
    self.isFrontCamera = [[args objectForKey: @"frontCamera"] boolValue];

    if ([@"getPlatformVersion" isEqualToString:call.method]) {
        result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    } else if ([@"readQRCode" isEqualToString:call.method]) {
        [self showQRCodeView:call];
        _result = result;
    } else if ([@"stopReading" isEqualToString:call.method]) {
        [self stopReading];
        result(@"stopped");
    }else {
        result(FlutterMethodNotImplemented);
    }
}


- (instancetype)initWithViewController:(UIViewController *)viewController {
    self = [super init];
    if (self) {
        _viewController = viewController;
        _viewController.view.backgroundColor = [UIColor clearColor];
        _viewController.view.opaque = NO;
        [[ NSNotificationCenter defaultCenter]addObserver: self selector:@selector(rotate:)
                                              name:UIDeviceOrientationDidChangeNotification object:nil];
    }
    return self;
}


- (void)showQRCodeView:(FlutterMethodCall*)call {
    _qrcodeViewController = [[UIViewController alloc] init];
    [_viewController presentViewController:_qrcodeViewController animated:NO completion:nil];
    [self loadViewQRCode];
    [self viewQRCodeDidLoad];
    [self startReading];
}


- (void)closeQRCodeView {
    [_qrcodeViewController dismissViewControllerAnimated:YES completion:^{
        [channel invokeMethod:@"onDestroy" arguments:nil];
    }];
}


-(void)loadViewQRCode {
    portraitheight = height = [UIScreen mainScreen].applicationFrame.size.height;
    landscapeheight = width = [UIScreen mainScreen].applicationFrame.size.width;
    //zq modify start
    borderWidth = width/2;
    borderWidth = width/2;
    borderHeight = width/2;
    borderX = width/2-borderWidth/2;
    borderY = height/2-borderWidth/2;
    //zq modify end
    
    if(UIDeviceOrientationIsLandscape([[UIDevice currentDevice] orientation])){
        landscapeheight = height;
        portraitheight = width;
    }
    _qrcodeview= [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height) ];
    _qrcodeview.opaque = NO;
    _qrcodeview.backgroundColor = [UIColor whiteColor];
    _qrcodeViewController.view = _qrcodeview;
}


- (void)viewQRCodeDidLoad {
    _viewPreview = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height+height/10) ];
    _viewPreview.backgroundColor = [UIColor whiteColor];
    [_qrcodeViewController.view addSubview:_viewPreview];
    _buttonCancel = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    _buttonCancel.frame = CGRectMake(width/2-width/8, height-height/20, width/4, height/20);
    [_buttonCancel setTitle:@"CANCEL"forState:UIControlStateNormal];
    [_buttonCancel addTarget:self action:@selector(stopReading) forControlEvents:UIControlEventTouchUpInside];
    [_qrcodeViewController.view addSubview:_buttonCancel];
    _captureSession = nil;
    _isReading = NO;
    
    //zq modify start
    UIImageView *borderView = [[UIImageView alloc] initWithFrame:CGRectMake(borderX, borderY, borderWidth, borderHeight)];
    [borderView setImage:[UIImage imageNamed:@"scanborder"]];
    [_qrcodeViewController.view addSubview:borderView];
    
    //扫描框里的动态效果
    _scanLineView = [[UIView alloc] initWithFrame:CGRectMake(borderX+3, borderY, borderWidth-6, 1)];
    [_scanLineView setBackgroundColor:[UIColor colorWithRed:151/255.0 green:208/255.0 blue:239/255.0 alpha:1] ];//#1296db
    [_qrcodeViewController.view addSubview:_scanLineView];
    
    [self startTimer];
    //zq modify end
}

//zq modify start
// 启动定时器
-(void)startTimer{
    _nsTime = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateTime:) userInfo:@"" repeats:YES];
}

-(void)updateTime:(NSTimer*) timer{
    CGFloat tmp = _scanLineView.frame.origin.y + 5.0;
    if(tmp-borderY>=borderHeight){
        [_scanLineView setFrame:CGRectMake(borderX+3, borderY, borderWidth-6, 1)];
    }else{
       [_scanLineView setFrame:CGRectMake(borderX+3, tmp, borderWidth-6, 1)];
    }
    
    
}

// 停止定时器
-(void)stopTimer{
    [_nsTime invalidate];
}
//zq modify end

- (BOOL)startReading {
    if (_isReading) return NO;
    _isReading = YES;
    NSError *error;
    AVCaptureDevice *captureDevice;
    if ([self isFrontCamera]) {
        captureDevice = [AVCaptureDevice defaultDeviceWithDeviceType: AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                                                mediaType: AVMediaTypeVideo
                                                                                position: AVCaptureDevicePositionFront];
    } else {
        captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }

    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    if (!input) {
        NSLog(@"%@", [error localizedDescription]);
        return NO;
    }
    _captureSession = [[AVCaptureSession alloc] init];
    [_captureSession addInput:input];
    AVCaptureMetadataOutput *captureMetadataOutput = [[AVCaptureMetadataOutput alloc] init];
    [_captureSession addOutput:captureMetadataOutput];
    dispatch_queue_t dispatchQueue;
    dispatchQueue = dispatch_queue_create("myQueue", NULL);
    [captureMetadataOutput setMetadataObjectsDelegate:self queue:dispatchQueue];
    [captureMetadataOutput setMetadataObjectTypes:[NSArray arrayWithObject:AVMetadataObjectTypeQRCode]];
    _videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    [_videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [_videoPreviewLayer setFrame:_viewPreview.layer.bounds];
    [_viewPreview.layer addSublayer:_videoPreviewLayer];
    [_captureSession startRunning];
    return YES;
}


-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    if (metadataObjects != nil && [metadataObjects count] > 0) {
        AVMetadataMachineReadableCodeObject *metadataObj = [metadataObjects objectAtIndex:0];
        if ([[metadataObj type] isEqualToString:AVMetadataObjectTypeQRCode]) {
            _result([metadataObj stringValue]);
            [self performSelectorOnMainThread:@selector(stopReading) withObject:nil waitUntilDone:NO];
            _isReading = NO;
        }
    }
}


- (void) rotate:(NSNotification *) notification{
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    if (orientation == 1) {
        height = portraitheight;
        width = landscapeheight;
        _buttonCancel.frame = CGRectMake(width/2-width/8, height-height/20, width/4, height/20);
    } else {
        height = landscapeheight;
        width = portraitheight;
        _buttonCancel.frame = CGRectMake(width/2-width/8, height-height/10, width/4, height/20);
    }
    _qrcodeview.frame = CGRectMake(0, 0, width, height) ;
    _viewPreview = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height+height/10) ];
    [_videoPreviewLayer setFrame:_viewPreview.layer.bounds];
    [_qrcodeViewController viewWillLayoutSubviews];
}


-(void)stopReading{
    [_captureSession stopRunning];
    _captureSession = nil;
    [_videoPreviewLayer removeFromSuperlayer];
    _isReading = NO;
    [self closeQRCodeView];
    _result(nil);
    [self stopTimer];//关闭扫描组件的动画
}


@end
