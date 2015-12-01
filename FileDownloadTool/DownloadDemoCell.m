//
//  DownloadDemoCell.m
//  FileDownloadTool
//
//  Created by 王琦 on 15/11/23.
//  Copyright © 2015年 王琦. All rights reserved.
//

#import "DownloadDemoCell.h"

@interface DownloadDemoCell ()

@property (weak, nonatomic) IBOutlet UIImageView *stateImageView;
@property (weak, nonatomic) IBOutlet UILabel *stateLabel;
@property (weak, nonatomic) IBOutlet UILabel *fileNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *downloadSpeedLabel;
@property (weak, nonatomic) IBOutlet UILabel *fileSizeLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *proressView;
@property (assign, nonatomic) FileDownloadState downloadState;

@end

@implementation DownloadDemoCell

- (void)awakeFromNib {
    // Initialization code
}

- (void)updateViewWithDownloadState
{
    if(_downloadState!=_downloadObject.downloadState){
        _downloadState = _downloadObject.downloadState;
        switch (_downloadState) {
            case FileDownloadStateWaiting: {
                _stateLabel.text = @"等待中";
                _stateImageView.image = [UIImage imageNamed:@"off_line_waiting"];
                break;
            }
            case FileDownloadStateDownloading: {
                _stateLabel.text = @"下载中";
                _stateImageView.image = [UIImage imageNamed:@"off_line_downloading"];
                break;
            }
            case FileDownloadStateSuspending: {
                _stateLabel.text = @"暂停中";
                _stateImageView.image = [UIImage imageNamed:@"off_line_pausing"];
                break;
            }
            case FileDownloadStateFail: {
                _stateLabel.text = @"下载失败";
                _stateImageView.image = [UIImage imageNamed:@"off_line_download_fail"];
                break;
            }
            case FileDownloadStateFinish: {
                _stateLabel.text = @"下载完成";
                _stateImageView.image = [UIImage imageNamed:@"off_line_download_fail"];
                break;
            }
            default: {
                break;
            }
        }
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)displayCellFromDownloadObject:(DownloadDemoObject *)downloadObject
{
    self.downloadObject = downloadObject;
    [self updateViewWithDownloadState];
    _fileNameLabel.text = downloadObject.fileName;
    _proressView.progress = _downloadObject.progress;
    _downloadSpeedLabel.text = _downloadObject.downloadSpeed;
    _fileSizeLabel.text = [NSString stringWithFormat:@"%@/%@",_downloadObject.downloadSize,_downloadObject.totalSize];
}

@end










