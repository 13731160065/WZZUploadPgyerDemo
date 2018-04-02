//
//  ViewController.m
//  WZZHFUploadIPA
//
//  Created by 王泽众 on 2018/4/2.
//  Copyright © 2018年 王泽众. All rights reserved.
//

#import "ViewController.h"
#import "WZZHttpTool.h"
#import "WZZMakePlistVC.h"

@interface ViewController ()<NSTableViewDelegate, NSTableViewDataSource> {
    NSMutableArray * dataArr;
}
@property (weak) IBOutlet NSTableView *mainTableView;
@property (weak) IBOutlet NSButton *uploadButton;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    dataArr = [NSMutableArray array];
}

- (IBAction)choseF:(id)sender {
    [self choseFileClick];
}

- (IBAction)submitClick:(id)sender {
    __block NSInteger iii = 0;
    const NSInteger alliii = dataArr.count;
    _uploadButton.title = @"上传中";
    _uploadButton.enabled = NO;
    for (int i = 0; i < dataArr.count; i++) {
        NSDictionary * dic = dataArr[i];
        NSString * path = dic[@"path"];
        NSString * apiKey = dic[@"apikey"];
        if (path && apiKey) {
            NSData * data = [NSData dataWithContentsOfFile:path];
            [WZZHttpTool POST:@"http://www.pgyer.com/apiv2/app/upload" addFormData:^(WZZPOSTFormData *formData) {
                [formData addData:data key:@"file" fileName:@"abc.ipa" type:@"application/octet-stream"];
            } httpBody:@{@"_api_key":apiKey} successBlock:^(id httpResponse) {
                NSAlert * alert = [[NSAlert alloc] init];
                alert.messageText = @"上传文件成功";
                alert.informativeText = [NSString stringWithFormat:@"%@", httpResponse];
                [alert addButtonWithTitle:@"确定"];
                alert.alertStyle = NSAlertStyleInformational;
                [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
                iii++;
                if (iii == alliii) {
                    //完成
                    _uploadButton.title = @"上传";
                    _uploadButton.enabled = YES;
                }
            } failedBlock:^(NSError *httpError) {
                NSAlert * alert = [[NSAlert alloc] init];
                alert.messageText = @"上传文件失败";
                alert.informativeText = [NSString stringWithFormat:@"%@", httpError];
                [alert addButtonWithTitle:@"确定"];
                alert.alertStyle = NSAlertStyleCritical;
                [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
                iii++;
                if (iii == alliii) {
                    //完成
                    _uploadButton.title = @"上传";
                    _uploadButton.enabled = YES;
                }
            }];
        }
    }
    NSLog(@"上传");
}

- (IBAction)makePlist:(id)sender {
    WZZMakePlistVC * plistVC = [[WZZMakePlistVC alloc] init];
    [self presentViewControllerAsSheet:plistVC];
}

- (void)choseFileClick {
    //导入
    NSOpenPanel* openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowedFileTypes:@[@"plist"]];
    [openPanel setMessage:@"选择配置文件"];
    [openPanel setPrompt:@"选择"];
    NSInteger result = [openPanel runModal];
    
    if (result == NSModalResponseOK) {
        NSURL * url = openPanel.URL;
        NSDictionary * dic = [NSDictionary dictionaryWithContentsOfURL:url];
        NSString * path = dic[@"path"];
        NSString * apiKey = dic[@"apikey"];
        if (!path) {
            return;
        }
        if (!apiKey) {
            return;
        }
        [dataArr addObject:dic];
    }
    [_mainTableView reloadData];
}

#pragma mark - tableview代理
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return dataArr.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSDictionary * dic = dataArr[row];
    NSString * name = dic[@"name"];
    NSString * path = dic[@"path"];
    NSString * apiKey = dic[@"apikey"];
    NSString * str = [NSString stringWithFormat:@"%@ | %@ | %@", name, path, apiKey];
    return str;
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    [dataArr removeObjectAtIndex:row];
    [tableView reloadData];
    return NO;
}

@end
