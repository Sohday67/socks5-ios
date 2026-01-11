//
//  VPNManager.m
//  SOCKS
//
//  Manages the VPN tunnel connection to bypass iOS device isolation
//

#import "VPNManager.h"

@interface VPNManager ()
@property (nonatomic, strong) NETunnelProviderManager *tunnelManager;
@property (nonatomic, readwrite) VPNConnectionStatus status;
@end

@implementation VPNManager

+ (instancetype)sharedManager {
    static VPNManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[VPNManager alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _status = VPNConnectionStatusDisconnected;
        _serverPort = 9876;
        
        // Observe VPN status changes
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(vpnStatusDidChange:)
                                                     name:NEVPNStatusDidChangeNotification
                                                   object:nil];
        
        // Load existing configuration
        [self loadTunnelManager];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadTunnelManager {
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Failed to load tunnel managers: %@", error);
            return;
        }
        
        if (managers.count > 0) {
            self.tunnelManager = managers.firstObject;
            [self updateStatusFromManager];
        }
    }];
}

- (void)configureVPNWithServerAddress:(NSString *)address port:(NSUInteger)port completion:(void (^)(NSError * _Nullable))completion {
    self.serverAddress = address;
    self.serverPort = port;
    
    // Check if we have an existing manager
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
        if (error) {
            if (completion) completion(error);
            return;
        }
        
        NETunnelProviderManager *manager = managers.firstObject ?: [[NETunnelProviderManager alloc] init];
        
        // Configure the tunnel protocol
        NETunnelProviderProtocol *protocol = [[NETunnelProviderProtocol alloc] init];
        protocol.providerBundleIdentifier = @"ca.robertxiao.socks-ios.PacketTunnel";
        protocol.serverAddress = address;
        protocol.providerConfiguration = @{
            @"serverAddress": address,
            @"serverPort": @(port)
        };
        
        manager.protocolConfiguration = protocol;
        manager.localizedDescription = @"SOCKS5 VPN";
        manager.enabled = YES;
        
        // Save the configuration
        [manager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"Failed to save VPN configuration: %@", error);
                if (completion) completion(error);
                return;
            }
            
            // Reload to ensure changes are applied
            [manager loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
                if (error) {
                    NSLog(@"Failed to reload VPN configuration: %@", error);
                }
                self.tunnelManager = manager;
                if (completion) completion(error);
            }];
        }];
    }];
}

- (void)connectWithCompletion:(void (^)(NSError * _Nullable))completion {
    if (!self.tunnelManager) {
        NSError *error = [NSError errorWithDomain:@"VPNManager" 
                                             code:1 
                                         userInfo:@{NSLocalizedDescriptionKey: @"VPN not configured"}];
        if (completion) completion(error);
        return;
    }
    
    self.status = VPNConnectionStatusConnecting;
    [self notifyStatusChange];
    
    NSError *startError = nil;
    [self.tunnelManager.connection startVPNTunnelAndReturnError:&startError];
    
    if (startError) {
        self.status = VPNConnectionStatusError;
        [self notifyStatusChange];
        if ([self.delegate respondsToSelector:@selector(vpnDidFailWithError:)]) {
            [self.delegate vpnDidFailWithError:startError];
        }
        if (completion) completion(startError);
    } else {
        if (completion) completion(nil);
    }
}

- (void)disconnect {
    if (self.tunnelManager) {
        [self.tunnelManager.connection stopVPNTunnel];
    }
}

- (BOOL)isConnected {
    return self.status == VPNConnectionStatusConnected;
}

#pragma mark - Status Updates

- (void)vpnStatusDidChange:(NSNotification *)notification {
    [self updateStatusFromManager];
}

- (void)updateStatusFromManager {
    if (!self.tunnelManager) {
        self.status = VPNConnectionStatusDisconnected;
        [self notifyStatusChange];
        return;
    }
    
    NEVPNStatus vpnStatus = self.tunnelManager.connection.status;
    
    switch (vpnStatus) {
        case NEVPNStatusDisconnected:
            self.status = VPNConnectionStatusDisconnected;
            break;
        case NEVPNStatusConnecting:
            self.status = VPNConnectionStatusConnecting;
            break;
        case NEVPNStatusConnected:
            self.status = VPNConnectionStatusConnected;
            break;
        case NEVPNStatusReasserting:
            self.status = VPNConnectionStatusConnecting;
            break;
        case NEVPNStatusDisconnecting:
            self.status = VPNConnectionStatusDisconnecting;
            break;
        case NEVPNStatusInvalid:
        default:
            self.status = VPNConnectionStatusDisconnected;
            break;
    }
    
    [self notifyStatusChange];
}

- (void)notifyStatusChange {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(vpnStatusDidChange:)]) {
            [self.delegate vpnStatusDidChange:self.status];
        }
    });
}

@end
