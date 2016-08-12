#import <UIKit/UIKit.h>
@import Firebase;

#import "peertalk/PTChannel.h"

@interface ViewController : UIViewController <PTChannelDelegate>

@property (strong, nonatomic) FIRDatabaseReference *ref;

@property (weak, nonatomic) IBOutlet UISwitch *killSwitch;
@property (weak, nonatomic) IBOutlet UILabel *messageLabel;

- (IBAction)onKillSwitched:(id)sender;

- (void)sendMessage:(NSString*)message;

@end
