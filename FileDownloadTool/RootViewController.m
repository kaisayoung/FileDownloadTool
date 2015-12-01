//
//  RootViewController.m
//  FileDownloadTool
//
//  Created by 王琦 on 15/11/20.
//  Copyright © 2015年 王琦. All rights reserved.
//

#import "RootViewController.h"

#define TEST_FILE_URL1   @"http://mw5.dwstatic.com/1/3/1528/133489-99-1436409822.mp4"
#define TEST_FILE_URL2   @"http://static.tripbe.com/videofiles/20121214/9533522808.f4v.mp4"
#define TEST_FILE_URL3   @"http://farm3.staticflickr.com/2846/9823925914_78cd653ac9_b_d.jpg"

@interface RootViewController ()<NSURLSessionDelegate,NSURLSessionDownloadDelegate>

@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UILabel *downloadStateLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UILabel *downloadProgressLabel;
@property (weak, nonatomic) IBOutlet UILabel *downloadSpeedLabel;
@property (weak, nonatomic) IBOutlet UILabel *downloadSizeLabel;
@property (weak, nonatomic) IBOutlet UIButton *startDownloadButton;
@property (weak, nonatomic) IBOutlet UIButton *suspendDownloadButton;
@property (weak, nonatomic) IBOutlet UIButton *deleteFileButton;

//文件下载路径，文件下载名称
@property (copy, nonatomic) NSString *filePath;
@property (copy, nonatomic) NSString *fileName;
//保存之前的数据
@property (strong, nonatomic) NSData *partialData;
//用于计算网速
@property (strong, nonatomic) NSTimer *timer;
@property (assign, nonatomic) uint64_t timerReceivedData;
//下载task
@property (strong, nonatomic) NSURLSessionDownloadTask *downloadTask;

- (IBAction)onStartDownloadButtonTapped:(id)sender;
- (IBAction)onSuspendDownloadButtonTapped:(id)sender;
- (IBAction)onDeleteFileButtonTapped:(id)sender;

@end

@implementation RootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _fileName = @"第一个文件.jpg";
    _filePath = [NSString stringWithFormat:@"%@/Library/Caches/SCDownloadFiles",NSHomeDirectory()];
    NSData *resumeData = [[NSUserDefaults standardUserDefaults] objectForKey:@"我就是试试"];
    if(resumeData){
        self.partialData = resumeData;
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"我就是看看"];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self.view endEditing:YES];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark --- NSURLSessionDelegate ---

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error
{
    if(error){
        NSString *desc = error.localizedDescription;
        NSLog(@"出错啦，错误信息：%@", desc);
    }
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
    //这里也是下载成功了
    NSLog(@"finally 成羹啦！");
}

#pragma mark --- NSURLSessionDownloadDelegate ---

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    _timerReceivedData += bytesWritten;
    [self updateProgressWithReceivedData:totalBytesWritten totalData:totalBytesExpectedToWrite];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
    NSString *offsetValue = [NSString stringWithFormat:@"%.1fMB",(CGFloat)fileOffset/1024.0/1024.0];
    NSLog(@"offsetValue is %@",offsetValue);
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    NSLog(@"download finish file location is %@",location);
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *tmpfilePath = [_filePath stringByAppendingPathComponent:[location lastPathComponent]];
    if([fileManager fileExistsAtPath:tmpfilePath isDirectory:NULL]){
        [fileManager removeItemAtPath:tmpfilePath error:NULL];
    }
    if([fileManager moveItemAtPath:[location path] toPath:tmpfilePath error:NULL]){
        self.downloadTask = nil;
        self.partialData = nil;
    }
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"我就是看看"];
}

#pragma mark --- NSURLSessionTaskDelegate ---

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    [self stopCalculateDownloadSpeed];
    if(error && error.code!=-999){
        NSLog(@"出错啦，错误信息：%ld,%@", error.code,error.localizedDescription);
    }
}

#pragma mark --- private method ---

- (NSURLSession *)defaultSession
{
    //「进程内会话（默认会话）」和「临时的进程内会话（内存）」，路径目录为：/tmp，可以通过 NSTemporaryDirectory() 方法获取
    NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    sessionConfiguration.timeoutIntervalForRequest = 60.0;
    sessionConfiguration.HTTPMaximumConnectionsPerHost = 1;
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:nil];
    session.sessionDescription = @"kDefaultSession";
    
    return session;
}

- (NSURLSession *)backgroundSession
{
    //「后台会话」，路径目录为：/Library/Caches/com.apple.nsurlsessiond/Downloads/com.wanwan.FileDownloadTool
    static NSURLSession *session = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"kBackgroundSessionID"];
        sessionConfiguration.allowsCellularAccess = NO;        //是否允许蜂窝网络访问（2G/3G/4G）
        sessionConfiguration.timeoutIntervalForRequest = 60.0; //请求超时时间；默认为60秒
        sessionConfiguration.HTTPMaximumConnectionsPerHost = 3;//限制每次最多连接数；在 iOS 中默认值为4
        sessionConfiguration.discretionary = YES;              //是否自动选择最佳网络访问，仅对「后台会话」有效
        
        session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:nil];
        session.sessionDescription = @"kBackgroundSession";
    });
    
    return session;
}

- (void)createDownloadTask
{
    if(!_downloadTask){
        if(self.partialData){
            _downloadTask = [[self backgroundSession] downloadTaskWithResumeData:self.partialData];
        }
        else{
            NSMutableURLRequest *fileRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:[TEST_FILE_URL1 stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
//            _downloadTask = [[self defaultSession] downloadTaskWithRequest:fileRequest];
            _downloadTask = [[self backgroundSession] downloadTaskWithRequest:fileRequest];
        }
    }
}

- (void)beginCalculateDownloadSpeed
{
    _timerReceivedData = 0;
    _timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(calculateDownloadSpeed) userInfo:nil repeats:YES];
}

- (void)stopCalculateDownloadSpeed
{
    if(_timer){
        [_timer invalidate];
        _timer = nil;
    }
}

- (void)calculateDownloadSpeed
{
    float downloadData = (float)_timerReceivedData/1024.0;
    NSString *downloadSpeed = @"";
    if(downloadData>=1024.0){
        downloadData /= 1024.0;
        downloadSpeed = [NSString stringWithFormat:@"%.1fMB/s",downloadData];
    }
    else{
        downloadSpeed = [NSString stringWithFormat:@"%.1fKB/s",downloadData];
    }
    _timerReceivedData = 0;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.downloadSpeedLabel.text = downloadSpeed;
    });
}

- (void)updateProgressWithReceivedData:(uint64_t)receivedData totalData:(int64_t)totalData
{
    CGFloat progress = (CGFloat)receivedData/(CGFloat)totalData;
    NSString *receivedSizeValue = [NSString stringWithFormat:@"%.1fMB",(CGFloat)receivedData/1024.0/1024.0];
    NSString *totalSizeValue = [NSString stringWithFormat:@"%.1fMB",(CGFloat)totalData/1024.0/1024.0];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progressView.progress = progress;
        self.downloadProgressLabel.text = [NSString stringWithFormat:@"%.1f%%",progress*100];
        self.downloadSizeLabel.text = [NSString stringWithFormat:@"%@/%@",receivedSizeValue,totalSizeValue];
    });
}

#pragma mark --- event method ---

- (IBAction)onStartDownloadButtonTapped:(id)sender
{
    //注意必须先点击开始－》暂停／取消－》开始，如此循环
    [self createDownloadTask];
    [self.downloadTask resume];
    [self beginCalculateDownloadSpeed];
}

- (IBAction)onSuspendDownloadButtonTapped:(id)sender
{
    //如果不考虑重启应用继续下载直接暂停即可
//    [self.downloadTask suspend];
//    [self stopCalculateDownloadSpeed];

    [self.downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        self.partialData = resumeData;
        self.downloadTask = nil;
        [[NSUserDefaults standardUserDefaults] setObject:self.partialData forKey:@"我就是试试"];
    }];
    [self stopCalculateDownloadSpeed];
}

- (IBAction)onDeleteFileButtonTapped:(id)sender
{
    [self.downloadTask cancel];
    self.downloadTask = nil;
    self.partialData = nil;
}

@end




























