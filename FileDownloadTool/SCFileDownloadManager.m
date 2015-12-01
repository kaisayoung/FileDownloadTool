//
//  SCFileDownloadManager.m
//  FileDownloadTool
//
//  Created by 王琦 on 15/11/20.
//  Copyright © 2015年 王琦. All rights reserved.
//

#import "SCFileDownloadManager.h"

/*
 一个operation在Queue中正在等待，绝对不允许对他的状态做任何改变！！绝对不允许对他的状态做任何改变！！绝对不允许对他的状态做任何改变！！
 这里指的是isFinished关联的状态 KVO绝对不能在未执行start方法之前就改动
 If you call “start” on an instance of NSOperation, without adding it to a queue, the operation will run in the main loop.
 尽管 operation 是支持取消操作的，但却并不是立即取消的，而是在你调用了 operation 的 cancel 方法之后的下一个 isCancelled 的检查点取消的。
 通俗地说，就是有延迟！！有延迟！！有延迟！！
*/

//默认最大同时下载数，最好不超过3
#define  DefaultMaxDownloadCount    1

//点击等待状态，暂停状态时响应方法：通常来说有两种情况，1种是点击立即去下载；另1种是点击等待中项无响应（因为已经存在于下载队列，只是还没排上队），点击暂停中项重新添加到下载队列。可在1和0之间切换
#define  RESPONSE_TO_CLICK_WAY      1

@interface SCFileDownloadManager ()<SCFileDownloadDelegate>

@property (strong, nonatomic) NSOperationQueue *downloadQueue;            //下载队列
@property (strong, nonatomic) NSMutableArray *suspendDownloadArr;         //取消的下载

@end

@implementation SCFileDownloadManager

+ (instancetype)sharedFileDownloadManager
{
    static dispatch_once_t onceToken;
    static SCFileDownloadManager *fileDownloadManager = nil;
    dispatch_once(&onceToken, ^{
        fileDownloadManager = [[SCFileDownloadManager alloc] init];
    });
    return fileDownloadManager;
}

- (instancetype)init
{
    if(self = [super init]){
        _suspendDownloadArr = [NSMutableArray array];
        _downloadQueue = [[NSOperationQueue alloc] init];
        _downloadQueue.maxConcurrentOperationCount = DefaultMaxDownloadCount;
    }
    return self;
}

#pragma mark --- Publick Download ---

- (void)addDownloadWithFileId:(NSString *)fileId fileUrl:(NSString *)url directoryPath:(NSString *)directoryPath fileName:(NSString *)fileName
{
    SCFileDownload *fileDownload = [[SCFileDownload alloc] initWithURL:url directoryPath:directoryPath fileName:fileName delegate:self];
    fileDownload.fileId = fileId;
    [_downloadQueue addOperation:fileDownload];
}

- (void)startDownloadWithFileId:(NSString *)fileId
{
    if(RESPONSE_TO_CLICK_WAY){
        return;
    }
    if(self.currentDownloadCount==0){
        return;
    }
    NSInteger currentDownloadCount = self.currentDownloadCount;
    NSMutableArray *tmpCancelArray = [NSMutableArray array];
    SCFileDownload *chooseDownload = nil;
    for(NSInteger i=self.maxDownloadCount;i<currentDownloadCount;i++){
        SCFileDownload *fileDownload = [_downloadQueue.operations objectAtIndex:i];
        [fileDownload cancel];
        if([fileDownload.fileId isEqualToString:fileId]){
            chooseDownload = fileDownload;
        }
        else{
           [tmpCancelArray addObject:fileDownload];
        }
    }
    SCFileDownload *fileDownload = [_downloadQueue.operations objectAtIndex:self.maxDownloadCount-1];
    [fileDownload cancelDownloadIfDeleteFile:NO];
    [self addToDownloadWithFileDownload:chooseDownload];
    [self addToDownloadWithFileDownload:fileDownload];
    for(SCFileDownload *fileDownload in tmpCancelArray){
        [self addToDownloadWithFileDownload:fileDownload];
    }
}

- (void)suspendDownloadWithFileId:(NSString *)fileId
{
    for(SCFileDownload *fileDownload in _downloadQueue.operations){
        if([fileDownload.fileId isEqualToString:fileId]){
            [fileDownload cancelDownloadIfDeleteFile:NO];
            [_suspendDownloadArr addObject:fileDownload];
            break;
        }
    }
}

- (void)recoverDownloadWithFileId:(NSString *)fileId
{
    if(RESPONSE_TO_CLICK_WAY){
        [self addToDownloadInSuspendArrayWithFileId:fileId];
        return;
    }
    if([self canAddOperationWithoutCancel]){
        [self addToDownloadInSuspendArrayWithFileId:fileId];
    }
    else if([self hasWaitingOperations]){
        NSInteger currentDownloadCount = self.currentDownloadCount;
        NSMutableArray *tmpCancelArray = [NSMutableArray array];
        for(NSInteger i=self.maxDownloadCount;i<currentDownloadCount;i++){
            SCFileDownload *fileDownload = [_downloadQueue.operations objectAtIndex:i];
            [fileDownload cancel];
            [tmpCancelArray addObject:fileDownload];
        }
        SCFileDownload *fileDownload = [_downloadQueue.operations objectAtIndex:self.maxDownloadCount-1];
        [fileDownload cancelDownloadIfDeleteFile:NO];
        [self addToDownloadInSuspendArrayWithFileId:fileId];
        [self addToDownloadWithFileDownload:fileDownload];
        for(SCFileDownload *fileDownload in tmpCancelArray){
            [self addToDownloadWithFileDownload:fileDownload];
        }
    }
    else{
        SCFileDownload *fileDownload = [_downloadQueue.operations lastObject];
        [fileDownload cancelDownloadIfDeleteFile:NO];
        [self addToDownloadInSuspendArrayWithFileId:fileId];
        [self addToDownloadWithFileDownload:fileDownload];
    }
}

- (void)cancelDownloadWithFileId:(NSString *)fileId
{
    //先从下载队列中寻找
    NSString *filePath = @"";
    for(SCFileDownload *fileDownload in _downloadQueue.operations){
        if([fileDownload.fileId isEqualToString:fileId]){
            filePath = [self tmpFilePathWithDirectoryPath:fileDownload.directoryPath fileName:fileDownload.fileName];
            [fileDownload cancelDownloadIfDeleteFile:YES];
            [self removeTmpFileWithPath:filePath];
            return;
        }
    }
    //再从暂停列表中寻找
    for(SCFileDownload *fileDownload in _suspendDownloadArr){
        if([fileDownload.fileId isEqualToString:fileId]){
            filePath = [self tmpFilePathWithDirectoryPath:fileDownload.directoryPath fileName:fileDownload.fileName];
            [_suspendDownloadArr removeObject:fileDownload];
            [self removeTmpFileWithPath:filePath];
            return;
        }
    }
}

- (void)suspendAllFilesDownload
{
    //需要区分是正在执行的还是等待的，先把排队中的cancel掉，再把正在执行的finish掉
    if([self hasWaitingOperations]){
        NSInteger currentDownloadCount = self.currentDownloadCount;
        NSMutableArray *tmpCancelArray = [NSMutableArray array];
        for(NSInteger i=self.maxDownloadCount;i<currentDownloadCount;i++){
            SCFileDownload *fileDownload = [_downloadQueue.operations objectAtIndex:i];
            [fileDownload cancel];
            [_suspendDownloadArr addObject:fileDownload];
        }
        NSMutableArray *downloadingCancelArray = [NSMutableArray array];
        for(NSInteger i=0;i<self.maxDownloadCount;i++){
            SCFileDownload *fileDownload = [_downloadQueue.operations objectAtIndex:i];
            [downloadingCancelArray addObject:fileDownload];
        }
        for(SCFileDownload *fileDownload in downloadingCancelArray){
            [fileDownload cancelDownloadIfDeleteFile:NO];
        }
        [tmpCancelArray addObjectsFromArray:downloadingCancelArray];
        [tmpCancelArray addObjectsFromArray:_suspendDownloadArr];
        self.suspendDownloadArr = tmpCancelArray;
    }
    else{
        for(SCFileDownload *fileDownload in _downloadQueue.operations){
            [fileDownload cancelDownloadIfDeleteFile:NO];
            [_suspendDownloadArr addObject:fileDownload];
        }
    }
}

- (void)recoverAllFilesDownload
{
    for(SCFileDownload *fileDownload in _suspendDownloadArr){
        [self addToDownloadWithFileDownload:fileDownload];
    }
    [_suspendDownloadArr removeAllObjects];
}

- (void)cancelAllFilesDownload
{
    //先把排队的取消掉，再把正在下载的取消掉
    if([self hasWaitingOperations]){
        NSInteger currentDownloadCount = self.currentDownloadCount;
        for(NSInteger i=self.maxDownloadCount;i<currentDownloadCount;i++){
            SCFileDownload *fileDownload = [_downloadQueue.operations objectAtIndex:i];
            NSString *filePath = [self tmpFilePathWithDirectoryPath:fileDownload.directoryPath fileName:fileDownload.fileName];
            [fileDownload cancel];
            [self removeTmpFileWithPath:filePath];
        }
        NSMutableArray *downloadingCancelArray = [NSMutableArray array];
        for(NSInteger i=0;i<self.maxDownloadCount;i++){
            SCFileDownload *fileDownload = [_downloadQueue.operations objectAtIndex:i];
            [downloadingCancelArray addObject:fileDownload];
        }
        for(SCFileDownload *fileDownload in downloadingCancelArray){
            NSString *filePath = [self tmpFilePathWithDirectoryPath:fileDownload.directoryPath fileName:fileDownload.fileName];
            [fileDownload cancelDownloadIfDeleteFile:YES];
            [self removeTmpFileWithPath:filePath];
        }
    }
    else{
        for(SCFileDownload *fileDownload in _downloadQueue.operations){
            [fileDownload cancelDownloadIfDeleteFile:YES];
        }
    }
    for(SCFileDownload *fileDownload in _suspendDownloadArr){
        NSString *filePath = [self tmpFilePathWithDirectoryPath:fileDownload.directoryPath fileName:fileDownload.fileName];
        [self removeTmpFileWithPath:filePath];
    }
    [_suspendDownloadArr removeAllObjects];
}

- (FileDownloadState)getFileDownloadStateWithFileId:(NSString *)fileId
{
    //下载列表中包括正在下载和等待下载中，已经完成的不论成功或失败均不在此列
    for(SCFileDownload *fileDownload in _suspendDownloadArr){
        if([fileDownload.fileId isEqualToString:fileId]){
            return FileDownloadStateSuspending;
        }
    }
    
    NSInteger findCount = 0;
    NSInteger findIndex = 0;
    for(int i=0;i<self.currentDownloadCount;i++){
        if(i>=_downloadQueue.operations.count){
            return FileDownloadStateWaiting;
        }
        SCFileDownload *fileDownload = [_downloadQueue.operations objectAtIndex:i];
        if([fileDownload.fileId isEqualToString:fileId]){
            findCount++;
            findIndex=i;
        }
    }
    
    if(findCount==1 && findIndex<self.maxDownloadCount){
        return FileDownloadStateDownloading;
    }
    
    return FileDownloadStateWaiting;
}

#pragma mark --- Private Method ---

- (BOOL)hasWaitingOperations
{
    return self.currentDownloadCount>self.maxDownloadCount;
}

- (BOOL)canAddOperationWithoutCancel
{
    return self.maxDownloadCount>self.currentDownloadCount;
}

- (NSString *)tmpFilePathWithDirectoryPath:(NSString *)directoryPath fileName:(NSString *)fileName
{
    return [directoryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_tmp",fileName]];
}

- (void)removeTmpFileWithPath:(NSString *)tmpFilePath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if([fileManager fileExistsAtPath:tmpFilePath]){
        [fileManager removeItemAtPath:tmpFilePath error:nil];
    }
}

- (void)addToDownloadInSuspendArrayWithFileId:(NSString *)fileId
{
    for(int i=0; i<_suspendDownloadArr.count; i++) {
        SCFileDownload *download = _suspendDownloadArr[i];
        if([download.fileId isEqualToString:fileId]){
            [self addDownloadWithFileId:fileId fileUrl:download.fileUrl directoryPath:download.directoryPath fileName:download.fileName];
            [_suspendDownloadArr removeObject:download];
            download = nil;
            return;
        }
    }
}

- (void)addToDownloadWithFileDownload:(SCFileDownload *)fileDownload
{
    [self addDownloadWithFileId:fileDownload.fileId fileUrl:fileDownload.fileUrl directoryPath:fileDownload.directoryPath fileName:fileDownload.fileName];
}

#pragma mark --- Set & Get ---

- (void)setMaxDownloadCount:(NSInteger)maxDownloadCount
{
    _downloadQueue.maxConcurrentOperationCount = maxDownloadCount;
}

- (NSInteger)maxDownloadCount
{
    return _downloadQueue.maxConcurrentOperationCount;
}

- (NSInteger)currentDownloadCount
{
    return [_downloadQueue.operations count];
}

#pragma mark --- SCFileDownloadDelegate ---

- (void)fileDownloadStart:(SCFileDownload *)download hasDownloadComplete:(BOOL)downloadComplete
{
    if(downloadComplete){
        [self fileDownloadFinish:download success:YES error:nil];
    }
    else{
        dispatch_async(dispatch_get_main_queue(), ^{
            if(_delegate && [_delegate respondsToSelector:@selector(fileDownloadManagerStartDownload:)]){
                [_delegate fileDownloadManagerStartDownload:download];
            }
        });
    }
}

- (void)fileDownloadReceiveResponse:(SCFileDownload *)download FileSize:(uint64_t)totalLength
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if(_delegate && [_delegate respondsToSelector:@selector(fileDownloadManagerReceiveResponse:FileSize:)]){
            [_delegate fileDownloadManagerReceiveResponse:download FileSize:totalLength];
        }
    });
}

- (void)fileDownloadUpdate:(SCFileDownload *)download didReceiveData:(uint64_t)receiveLength downloadSpeed:(NSString *)downloadSpeed
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if(_delegate && [_delegate respondsToSelector:@selector(fileDownloadManagerUpdateProgress:didReceiveData:downloadSpeed:)]){
            [_delegate fileDownloadManagerUpdateProgress:download didReceiveData:receiveLength downloadSpeed:downloadSpeed];
        }
    });
}

- (void)fileDownloadFinish:(SCFileDownload *)download success:(BOOL)downloadSuccess error:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if(_delegate && [_delegate respondsToSelector:@selector(fileDownloadManagerFinishDownload:success:error:)]){
            [_delegate fileDownloadManagerFinishDownload:download success:downloadSuccess error:error];
        }
    });
}

@end













