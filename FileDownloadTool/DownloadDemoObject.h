//
//  DownloadDemoObject.h
//  FileDownloadTool
//
//  Created by 王琦 on 15/11/23.
//  Copyright © 2015年 王琦. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FileDemoModel.h"
#import "SCFileDownloadManager.h"

/*
 根据从网络获取的数据model类创建下载model类
 */

@interface DownloadDemoObject : NSObject

@property (copy, nonatomic) NSString *fileId;
@property (copy, nonatomic) NSString *fileName;
@property (copy, nonatomic) NSString *fileUrl;
@property (copy, nonatomic) NSString *totalSize;
@property (copy, nonatomic) NSString *downloadSize;
@property (copy, nonatomic) NSString *downloadSpeed;
@property (copy, nonatomic) NSString *directoryPath;
@property (assign, nonatomic) float progress;
@property (assign, nonatomic) uint64_t totalLength;
@property (assign, nonatomic) FileDownloadState downloadState;

- (id)initWithFileDemoModel:(FileDemoModel *)fileModel;

@end
