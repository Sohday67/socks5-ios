//
//  ViewController.m
//  SOCKS
//
//  Created by Robert Xiao on 8/19/18.
//  Copyright © 2018 Robert Xiao. All rights reserved.
//

#import "ViewController.h"
#import "AppDelegate.h"
#import "VPNManager.h"

@interface ViewController ()

@end

@implementation ViewController

extern int socks_main(int argc, const char** argv);

- (void)viewDidLoad {
    [super viewDidLoad];

    int port = 4884;
    
    // Set up instructions label if not connected via storyboard
    if (self.instructionsLabel) {
        self.instructionsLabel.numberOfLines = 0;
        self.instructionsLabel.textAlignment = NSTextAlignmentCenter;
    }
    
    // Set up VPN manager delegate
    [VPNManager sharedManager].delegate = self;
    
    // Set up server address field
    if (self.serverAddressField) {
        self.serverAddressField.placeholder = @"Mac IP (e.g., 192.168.1.100)";
        self.serverAddressField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        char portbuf[32];
        sprintf(portbuf, "%d", port);
        const char *argv[] = {"microsocks", "-p", portbuf, NULL};

        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *ipAddress = [AppDelegate deviceIPAddress];
            [self.statusLabel setText:[NSString stringWithFormat:@"Running at %@:%d", ipAddress, port]];
            
            // Show connection instructions with dynamic IP and port
            NSString *instructions = [NSString stringWithFormat:
                @"📡 Proxy: %@:%d\n\n"
                @"📖 Connection options:\n"
                @"• External router (recommended)\n"
                @"• USB tethering (iOS 16 and earlier)\n"
                @"• VPN mode below (iOS 17+)\n\n"
                @"See README for detailed setup.",
                ipAddress, port];
            
            if (self.instructionsLabel) {
                [self.instructionsLabel setText:instructions];
            }
        });

        int status = socks_main(3, argv);

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.statusLabel setText:[NSString stringWithFormat:@"Failed to start: %d", status]];
        });
    });

    /* Extremely hacky way to keep app running in the background.
     This WILL get the app rejected from the App Store! */
    NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"blank" ofType:@"wav"]];
    self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self.audioPlayer setVolume:0.01];
    [self.audioPlayer setNumberOfLoops:-1];
    [self.audioPlayer prepareToPlay];
    [self.audioPlayer play];
    
    // Update VPN status
    [self updateVPNStatusUI];
}

- (IBAction)toggleVPN:(id)sender {
    VPNManager *vpnManager = [VPNManager sharedManager];
    
    if ([vpnManager isConnected]) {
        [vpnManager disconnect];
    } else {
        NSString *serverAddress = self.serverAddressField.text;
        if (serverAddress.length == 0) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Server Address Required"
                                                                           message:@"Please enter your Mac's IP address.\n\nRun socks_vpn_server.py on your Mac to see the address."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }
        
        [self.vpnButton setEnabled:NO];
        [self.vpnStatusLabel setText:@"Configuring..."];
        
        [vpnManager configureVPNWithServerAddress:serverAddress port:9876 completion:^(NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    [self.vpnStatusLabel setText:@"Configuration failed"];
                    [self.vpnButton setEnabled:YES];
                    
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"VPN Error"
                                                                                   message:error.localizedDescription
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                    [self presentViewController:alert animated:YES completion:nil];
                    return;
                }
                
                [vpnManager connectWithCompletion:^(NSError * _Nullable error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.vpnButton setEnabled:YES];
                        if (error) {
                            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Connection Failed"
                                                                                           message:error.localizedDescription
                                                                                    preferredStyle:UIAlertControllerStyleAlert];
                            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                            [self presentViewController:alert animated:YES completion:nil];
                        }
                    });
                }];
            });
        }];
    }
}

- (void)updateVPNStatusUI {
    VPNManager *vpnManager = [VPNManager sharedManager];
    
    switch (vpnManager.status) {
        case VPNConnectionStatusDisconnected:
            [self.vpnStatusLabel setText:@"VPN: Disconnected"];
            [self.vpnButton setTitle:@"Connect VPN" forState:UIControlStateNormal];
            [self.vpnButton setEnabled:YES];
            break;
        case VPNConnectionStatusConnecting:
            [self.vpnStatusLabel setText:@"VPN: Connecting..."];
            [self.vpnButton setTitle:@"Connecting..." forState:UIControlStateNormal];
            [self.vpnButton setEnabled:NO];
            break;
        case VPNConnectionStatusConnected:
            [self.vpnStatusLabel setText:@"VPN: Connected ✓"];
            [self.vpnButton setTitle:@"Disconnect VPN" forState:UIControlStateNormal];
            [self.vpnButton setEnabled:YES];
            break;
        case VPNConnectionStatusDisconnecting:
            [self.vpnStatusLabel setText:@"VPN: Disconnecting..."];
            [self.vpnButton setTitle:@"Disconnecting..." forState:UIControlStateNormal];
            [self.vpnButton setEnabled:NO];
            break;
        case VPNConnectionStatusError:
            [self.vpnStatusLabel setText:@"VPN: Error"];
            [self.vpnButton setTitle:@"Connect VPN" forState:UIControlStateNormal];
            [self.vpnButton setEnabled:YES];
            break;
    }
}

#pragma mark - VPNManagerDelegate

- (void)vpnStatusDidChange:(VPNConnectionStatus)status {
    [self updateVPNStatusUI];
}

- (void)vpnDidFailWithError:(NSError *)error {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"VPN Error"
                                                                   message:error.localizedDescription
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
