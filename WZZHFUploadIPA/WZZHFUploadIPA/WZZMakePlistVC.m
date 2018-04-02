//
//  WZZMakePlistVC.m
//  WZZHFUploadIPA
//
//  Created by 王泽众 on 2018/4/2.
//  Copyright © 2018年 王泽众. All rights reserved.
//

#import "WZZMakePlistVC.h"

@interface WZZMakePlistVC ()
@property (weak) IBOutlet NSTextField *nameTF;
@property (weak) IBOutlet NSTextField *ipaTF;
@property (weak) IBOutlet NSTextField *apiKeyTF;

@end

@implementation WZZMakePlistVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
}

- (IBAction)okClick:(id)sender {
    NSMutableDictionary * dic = [NSMutableDictionary dictionary];
    dic[@"name"] = _nameTF.stringValue;
    dic[@"path"] = _ipaTF.stringValue;
    dic[@"apikey"] = _apiKeyTF.stringValue;
    
    NSSavePanel * savePanel = [NSSavePanel savePanel];
    [savePanel setAllowedFileTypes:@[@"plist"]];
    [savePanel setMessage:@"保存配置文件"];
    [savePanel setPrompt:@"保存"];
    NSInteger result = [savePanel runModal];
    
    if (result == NSModalResponseOK) {
        NSLog(@"%@", savePanel.URL.relativePath);
        [dic writeToURL:savePanel.URL atomically:YES];
        [self dismissViewController:self];
    }
}

- (IBAction)cancelClick:(id)sender {
    [self dismissViewController:self];
}

@end
