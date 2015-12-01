//
//  SCFileDownloadManager.h
//  FileDownloadTool
//
//  Created by 王琦 on 15/11/20.
//  Copyright © 2015年 王琦. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SCFileDownload.h"

/*
 文件下载管理类，只需引用这一个文件
 实际下载中，有可能文件名是一样的，所以用文件id作为唯一标识
 暂时未做网络变化相关逻辑；未做重启app恢复上次状态相关逻辑
 经过暴力测试发现还不够健壮，快速切换状态有bug，隔几s切换一次则OK
 */

typedef NS_ENUM(NSInteger, FileDownloadState){
    FileDownloadStateWaiting = 0,
    FileDownloadStateDownloading = 1,
    FileDownloadStateSuspending = 2,
    FileDownloadStateFail = 3,
    FileDownloadStateFinish = 4,
};

@protocol SCFileDownloadManagerDelegate <NSObject>

/*
 下载开始
 */
- (void)fileDownloadManagerStartDownload:(SCFileDownload *)download;
/*
 得到响应，获得文件大小等
 */
- (void)fileDownloadManagerReceiveResponse:(SCFileDownload *)download FileSize:(uint64_t)totalLength;
/*
 下载过程，更新进度
 */
- (void)fileDownloadManagerUpdateProgress:(SCFileDownload *)download didReceiveData:(uint64_t)receiveLength downloadSpeed:(NSString *)downloadSpeed;
/*
 下载完成，包括成功和失败
 */
- (void)fileDownloadManagerFinishDownload:(SCFileDownload *)download success:(BOOL)downloadSuccess error:(NSError *)error;

@end

@interface SCFileDownloadManager : NSObject

+ (instancetype)sharedFileDownloadManager;

@property (assign, nonatomic) NSInteger maxDownloadCount;                //当前队列最大同时下载数，默认值是1
@property (assign, nonatomic, readonly) NSInteger currentDownloadCount;  //当前队列中下载数，包括正在下载的和等待的
@property (assign, nonatomic) id<SCFileDownloadManagerDelegate>delegate;

//添加到下载队列
- (void)addDownloadWithFileId:(NSString *)fileId fileUrl:(NSString *)url directoryPath:(NSString *)directoryPath fileName:(NSString *)fileName;

//点击等待项（－》下载／do nothing）
- (void)startDownloadWithFileId:(NSString *)fileId;

//点击下载项 －》暂停
- (void)suspendDownloadWithFileId:(NSString *)fileId;

//点击暂停项（－》立刻下载／添加到下载队列）
- (void)recoverDownloadWithFileId:(NSString *)fileId;

//取消下载，且删除文件，只适用于未下载完成状态，下载完成的直接根据路径删除即可
- (void)cancelDownloadWithFileId:(NSString *)fileId;

//暂停全部
- (void)suspendAllFilesDownload;

//恢复全部
- (void)recoverAllFilesDownload;

//取消全部
- (void)cancelAllFilesDownload;

//获得状态
- (FileDownloadState)getFileDownloadStateWithFileId:(NSString *)fileId;

@end






















