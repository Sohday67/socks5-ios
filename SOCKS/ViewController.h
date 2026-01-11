//
//  ViewController.h
//  SOCKS
//
//  Created by Robert Xiao on 8/19/18.
//  Copyright © 2018 Robert Xiao. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "VPNManager.h"

@interface ViewController : UIViewController <VPNManagerDelegate>

@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UILabel *instructionsLabel;
@property (weak, nonatomic) IBOutlet UITextField *serverAddressField;
@property (weak, nonatomic) IBOutlet UIButton *vpnButton;
@property (weak, nonatomic) IBOutlet UILabel *vpnStatusLabel;
@property (strong) AVAudioPlayer *audioPlayer;

- (IBAction)toggleVPN:(id)sender;

@end

