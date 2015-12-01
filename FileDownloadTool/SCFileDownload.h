//
//  SCFileDownload.h
//  FileDownloadTool
//
//  Created by 王琦 on 15/11/20.
//  Copyright © 2015年 王琦. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
 文件下载类，具体在这个类中实现下载，下载一个文件时亦可直接用此类
 实现方式有NSURLConneciton和NSURLSession两种，本类实现了第一种，第二种待续
 */

typedef NS_ENUM(NSInteger, FileDownloadMethod){
    FileDownloadMethodURLConnection = 0,
    FileDownloadMethodURLSession = 1,
};

@class SCFileDownload;

@protocol SCFileDownloadDelegate <NSObject>

- (void)fileDownloadStart:(SCFileDownload *)download hasDownloadComplete:(BOOL)downloadComplete;
- (void)fileDownloadReceiveResponse:(SCFileDownload *)download FileSize:(uint64_t)totalLength;
- (void)fileDownloadUpdate:(SCFileDownload *)download didReceiveData:(uint64_t)receiveLength downloadSpeed:(NSString *)downloadSpeed;
- (void)fileDownloadFinish:(SCFileDownload *)download success:(BOOL)downloadSuccess error:(NSError *)error;

@end

@interface SCFileDownload : NSOperation

@property (copy, nonatomic) NSString *fileId;           //文件的唯一标识
@property (copy, nonatomic) NSString *fileUrl;          //文件的网址
@property (copy, nonatomic) NSString *fileName;         //文件的名字
@property (copy, nonatomic) NSString *directoryPath;    //文件所在文件夹路径
@property (assign, nonatomic) FileDownloadMethod downloadMethod;
@property (assign, nonatomic) id<SCFileDownloadDelegate>delegate;

- (id)initWithURL:(NSString *)fileUrl directoryPath:(NSString *)directoryPath fileName:(NSString *)fileName delegate:(id<SCFileDownloadDelegate>)delegate;

- (void)cancelDownloadIfDeleteFile:(BOOL)deleteFile;

@end




