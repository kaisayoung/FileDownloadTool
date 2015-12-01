//
//  DownloadDemoCell.h
//  FileDownloadTool
//
//  Created by 王琦 on 15/11/23.
//  Copyright © 2015年 王琦. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DownloadDemoObject.h"

@interface DownloadDemoCell : UITableViewCell

@property (strong, nonatomic) DownloadDemoObject *downloadObject;

- (void)displayCellFromDownloadObject:(DownloadDemoObject *)downloadObject;

@end

