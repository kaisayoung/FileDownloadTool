//
//  DownloadDemoObject.m
//  FileDownloadTool
//
//  Created by 王琦 on 15/11/23.
//  Copyright © 2015年 王琦. All rights reserved.
//

#import "DownloadDemoObject.h"

@implementation DownloadDemoObject

- (id)initWithFileDemoModel:(FileDemoModel *)fileModel
{
    if(self = [super init]){
        self.fileId = fileModel.fileId;
        self.fileUrl = fileModel.fileUrl;
        self.fileName = fileModel.fileName;
        self.downloadSize = @"0MB";
        self.totalSize = @"0MB";
        self.totalLength = 0.0;
        self.progress = 0.0;
        self.downloadState = FileDownloadStateWaiting;
    }
    return self;
}

@end
