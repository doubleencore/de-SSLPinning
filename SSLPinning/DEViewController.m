//
//  DEViewController.m
//  SSLPinning
//
//  Created by Jay Graves on 12/23/12.
//  Copyright (c) 2012 DoubleEncore. All rights reserved.
//

#import "DEViewController.h"


@interface DEViewController () <NSURLConnectionDataDelegate>
- (IBAction)MakeHTTPRequestTapped;
@property (weak, nonatomic) IBOutlet UITextView *textOutput;
@property (strong, nonatomic) NSURLConnection *connection;
@property (strong, nonatomic) NSMutableData *responseData;
@end


@implementation DEViewController


- (IBAction)MakeHTTPRequestTapped
{
    NSURL *httpsURL = [NSURL URLWithString:@"https://secure.skabber.com/json/"];
    NSURLRequest *request = [NSURLRequest requestWithURL:httpsURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:15.0f];
    self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
    [self.connection start];
    
    if ([self isSSLPinning]) {
        [self printMessage:@"Making pinned request"];
    }
    else {
        [self printMessage:@"Making non-pinned request"];
    }
}


- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    SecTrustRef serverTrust = challenge.protectionSpace.serverTrust;
    SecCertificateRef certificate = SecTrustGetCertificateAtIndex(serverTrust, 0);
    NSData *remoteCertificateData = CFBridgingRelease(SecCertificateCopyData(certificate));
    NSData *skabberCertData = [self skabberCert];
    
    if ([remoteCertificateData isEqualToData:skabberCertData] || [self isSSLPinning] == NO) {
        
        if ([self isSSLPinning] || [remoteCertificateData isEqualToData:skabberCertData]) {
            [self printMessage:@"The server's certificate is the valid secure.skabber.com certificate. Allowing the request."];
        }
        else {
            [self printMessage:@"The server's certificate does not match secure.skabber.com. Continuing anyway."];
        }
        
        NSURLCredential *credential = [NSURLCredential credentialForTrust:serverTrust];
        [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
    }
    else {
        [self printMessage:@"The server's certificate does not match secure.skabber.com. Canceling the request."];
        [[challenge sender] cancelAuthenticationChallenge:challenge];
    }
}


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (self.responseData == nil) {
        self.responseData = [NSMutableData dataWithData:data];
    }
    else {
        [self.responseData appendData:data];
    }
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSString *response = [[NSString alloc] initWithData:self.responseData encoding:NSUTF8StringEncoding];
    [self printMessage:response];
    self.responseData = nil;
}


- (NSData *)skabberCert
{
    NSString *cerPath = [[NSBundle mainBundle] pathForResource:@"secure.skabber.com" ofType:@"cer"];
    return [NSData dataWithContentsOfFile:cerPath];
}


- (void)printMessage:(NSString *)message
{
    NSString *existingMessage = self.textOutput.text;
    self.textOutput.text = [existingMessage stringByAppendingFormat:@"\n%@", message];
}


- (BOOL)isSSLPinning
{
    NSString *envValue = [[[NSProcessInfo processInfo] environment] objectForKey:@"SSL_PINNING"];
    return [envValue boolValue];
}


@end
