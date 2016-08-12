#import "ViewController.h"
#import "MissionControlProtocol.h"

@interface ViewController () {
    __weak PTChannel *serverChannel_;
    __weak PTChannel *peerChannel_;
}
- (void)showAlert:(NSString*)message;
- (void)sendMessage:(NSString*)message;
- (void)sendDeviceInfo;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setNeedsStatusBarAppearanceUpdate];

    // Create a new channel that is listening to our ip v4 port
    
    PTChannel *channel = [PTChannel channelWithDelegate:self];
    [channel listenOnPort:MissionControlProtocolIPv4PortNumber IPv4Address:INADDR_LOOPBACK callback:^(NSError *error) {
        if (error) {
            [self showAlert:[NSString stringWithFormat:@"Failed to listen on 127.0.0.1:%d: %@", MissionControlProtocolIPv4PortNumber, error]];
        } else {
            serverChannel_ = channel;
        }
    }];
    
    // Observe database changes
    
    self.ref = [[FIRDatabase database] reference];
    
    [[[self.ref child:@"questions"] queryLimitedToLast: 1] observeEventType:FIRDataEventTypeChildAdded withBlock:^(FIRDataSnapshot * _Nonnull snapshot) {
        NSString* message = snapshot.value[@"message"];
        NSString* timestamp = snapshot.value[@"timestamp"];
        NSString* payload = [NSString stringWithFormat:@"{\"message\":\"%@\", \"timestamp\":\"%@\"}", message, timestamp];
        
        self.messageLabel.text = message;
        [self sendMessage:payload];
    }];
    
    [[self.ref child:@"status"] observeEventType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot * _Nonnull snapshot) {
        NSNumber* isKilled = snapshot.value[@"killed"];
        self.killSwitch.on = isKilled.boolValue;
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
    if (serverChannel_) {
        [serverChannel_ close];
    }
    [super viewDidUnload];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (IBAction)onKillSwitched:(id)sender {
    [[[self.ref child:@"status"] child:@"killed"] setValue:[NSNumber numberWithInt:self.killSwitch.on]];
}

- (void)sendMessage:(NSString*)message {
    if (peerChannel_) {
        dispatch_data_t payload = MissionControlTextDispatchDataWithString(message);
        [peerChannel_ sendFrameOfType:MissionControlFrameTypeTextMessage tag:PTFrameNoTag withPayload:payload callback:^(NSError *error) {
            if (error) {
                [self showAlert:[NSString stringWithFormat:@"Failed to send message: %@", error]];
            }
        }];
    } else {
        [self showAlert:@"Can not send message — not connected"];
    }
}

- (void)showAlert:(NSString*)message {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Message"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {}];
    
    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Communicating

- (void)sendDeviceInfo {}

#pragma mark - PTChannelDelegate

// Invoked to accept an incoming frame on a channel. Reply NO ignore the
// incoming frame. If not implemented by the delegate, all frames are accepted.

- (BOOL)ioFrameChannel:(PTChannel*)channel shouldAcceptFrameOfType:(uint32_t)type tag:(uint32_t)tag payloadSize:(uint32_t)payloadSize {
    if (channel != peerChannel_) {
        // A previous channel that has been canceled but not yet ended. Ignore.
        return NO;
    } else if (type != MissionControlFrameTypeTextMessage && type != MissionControlFrameTypePing) {
        [self showAlert:[NSString stringWithFormat:@"Unexpected frame of type %u", type]];
        [channel close];
        return NO;
    } else {
        return YES;
    }
}

// Invoked when a new frame has arrived on a channel.

- (void)ioFrameChannel:(PTChannel*)channel didReceiveFrameOfType:(uint32_t)type tag:(uint32_t)tag payload:(PTData*)payload {
}

// Invoked when the channel closed. If it closed because of an error, *error* is
// a non-nil NSError object.

- (void)ioFrameChannel:(PTChannel*)channel didEndWithError:(NSError*)error {
    if (error) {
        [self showAlert:[NSString stringWithFormat:@"%@ ended with error: %@", channel, error]];
    } else {
        [self showAlert:[NSString stringWithFormat:@"Disconnected from %@", channel.userInfo]];
    }
}

// For listening channels, this method is invoked when a new connection has been
// accepted.

- (void)ioFrameChannel:(PTChannel*)channel didAcceptConnection:(PTChannel*)otherChannel fromAddress:(PTAddress*)address {
    // Cancel any other connection. We are FIFO, so the last connection
    // established will cancel any previous connection and "take its place".
    if (peerChannel_) {
        [peerChannel_ cancel];
    }
    
    // Weak pointer to current connection. Connection objects live by themselves
    // (owned by its parent dispatch queue) until they are closed.
    peerChannel_ = otherChannel;
    peerChannel_.userInfo = address;
    
    [self showAlert:[NSString stringWithFormat:@"Connected to %@", address]];
}

@end
