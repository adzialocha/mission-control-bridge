#ifndef MissionControlProtocol_h
#define MissionControlProtocol_h

#import <Foundation/Foundation.h>
#include <stdint.h>

static const int MissionControlProtocolIPv4PortNumber = 2345;

enum {
    MissionControlFrameTypeDeviceInfo = 100,
    MissionControlFrameTypeTextMessage = 101,
    MissionControlFrameTypePing = 102,
    MissionControlFrameTypePong = 103,
};

typedef struct _MissionControlTextFrame {
    uint32_t length;
    uint8_t utf8text[0];
} MissionControlTextFrame;

static dispatch_data_t MissionControlTextDispatchDataWithString(NSString *message) {
    const char *utf8text = [message cStringUsingEncoding:NSUTF8StringEncoding];
    size_t length = strlen(utf8text);
    MissionControlTextFrame *textFrame = CFAllocatorAllocate(nil, sizeof(MissionControlTextFrame) + length, 0);
    
    memcpy(textFrame->utf8text, utf8text, length); // Copy bytes to utf8text array
    textFrame->length = htonl(length); // Convert integer to network byte order
    
    // Wrap the textFrame in a dispatch data object
    return dispatch_data_create((const void*)textFrame, sizeof(MissionControlTextFrame) + length, nil, ^{
        CFAllocatorDeallocate(nil, textFrame);
    });
}

#endif /* MissionControlProtocol_h */
