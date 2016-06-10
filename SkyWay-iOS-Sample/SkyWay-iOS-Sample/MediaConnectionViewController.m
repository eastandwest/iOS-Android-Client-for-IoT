//
// MediaConnectionViewController.m
// SkyWay-iOS-Sample
//

#import "MediaConnectionViewController.h"

#import <AVFoundation/AVFoundation.h>

#import <SkyWay/SKWPeer.h>

#import "AppDelegate.h"
#import "PeersListViewController.h"


// Enter your APIkey and Domain
// Please check this page. >> https://skyway.io/ds/
static NSString *const kAPIkey = @"yourAPIKEY";
static NSString *const kDomain = @"yourDomain";


typedef NS_ENUM(NSUInteger, ViewTag)
{
	TAG_ID = 1000,
	TAG_WEBRTC_ACTION,
	TAG_REMOTE_VIDEO,
	TAG_LOCAL_VIDEO,
    TAG_AUDIO_BUTTON
};

typedef NS_ENUM(NSUInteger, AlertType)
{
	ALERT_ERROR,
	ALERT_CALLING,
};

@interface MediaConnectionViewController ()
< UINavigationControllerDelegate, UIAlertViewDelegate>
{
	SKWPeer*			_peer;
	SKWMediaStream*		_msLocal;
	SKWMediaStream*		_msRemote;
	SKWMediaConnection*	_mediaVideoConnection;
    SKWMediaConnection*	_mediaAudioConnection;
    
    SKWDataConnection* _dataConnection;
	
	NSString*			_strOwnId;
    NSString*           _remoteId;
    
    BOOL                _bDataConnected;
    BOOL				_bVideoConnected;
    BOOL                _bAudioConnected;
}

@end

@implementation MediaConnectionViewController


#pragma mark - Lifecycle

- (void)viewDidLoad
{
	[super viewDidLoad];
	_strOwnId = nil;
	
	[self.view setBackgroundColor:[UIColor whiteColor]];
	
	if (nil != self.navigationController)
	{
		[self.navigationController setDelegate:self];
	}
    
    //Initialize SkyWay Peer
    SKWPeerOption* option = [[SKWPeerOption alloc] init];
    option.key = kAPIkey;
    option.domain = kDomain;
    option.debug = SKW_DEBUG_LEVEL_ALL_LOGS;
    
    _peer	= [[SKWPeer alloc] initWithId:nil options:option];
    [self setCallbacks:_peer];
	[SKWNavigator initialize:_peer];
    
    [self initializeViews];
}


- (void)setCallbacks:(SKWPeer *)peer
{
    if (nil == peer)
    {
        return;
    }

    [peer on:SKW_PEER_EVENT_CONNECTION callback:^(NSObject* obj)
     {
         NSLog(@"SKW_PEER_EVENT_CONNECTION");
     }];
    

    [peer on:SKW_PEER_EVENT_CALL callback:^(NSObject* obj)
     {
         NSLog(@"SKW_PEER_EVENT_CALL");
         //Callが来たら、Streamはnilでanswer
         if (YES == [obj isKindOfClass:[SKWMediaConnection class]])
         {
             _mediaVideoConnection = (SKWMediaConnection *)obj;
             
             [self setMediaCallbacks:_mediaVideoConnection];
             [_mediaVideoConnection answer:nil];
         }
     }];
    
    
    [peer on:SKW_PEER_EVENT_OPEN callback:^(NSObject* obj)
     {
         dispatch_async(dispatch_get_main_queue(), ^
                        {
                            if (YES == [obj isKindOfClass:[NSString class]])
                            {
                                _strOwnId = (NSString *)obj;
                                
                                UILabel* lbl = (UILabel*)[self.view viewWithTag:TAG_ID];
                                if (nil != lbl)
                                {
                                    [lbl setText:[NSString stringWithFormat:@"your ID: \n%@", _strOwnId]];
                                    [lbl setNeedsDisplay];
                                }
                            }
                            
                            UIButton* btn = (UIButton*)[self.view viewWithTag:TAG_WEBRTC_ACTION];
                            if (nil != btn)
                            {
                                [btn setEnabled:YES];
                            }
                        });
     }];
    
    
    [peer on:SKW_PEER_EVENT_CLOSE callback:^(NSObject* obj)
     {
         NSLog(@"SKW_PEER_EVENT_CLOSE");
     }];
    
    [peer on:SKW_PEER_EVENT_DISCONNECTED callback:^(NSObject* obj)
     {
         NSLog(@"SKW_PEER_EVENT_DISCONNECTED");
     }];
    
    [peer on:SKW_PEER_EVENT_ERROR callback:^(NSObject* obj)
     {
         NSLog(@"SKW_PEER_EVENT_ERROR:%@",obj);
     }];
    
}


//listAllPeersをして、PeerListViewControllerに渡す
//PeerListViewControllerから(void)callingTo:(NSString *)strDestIdが呼ばれる。
- (void)onTouchCallButton:(NSObject *)sender
{
    UIButton* btn = (UIButton *)sender;
    
    if (TAG_WEBRTC_ACTION == btn.tag)
    {
        if (_bDataConnected == NO)
        {
            // Listing all peers
            [_peer listAllPeers:^(NSArray* aryPeers)
             {
                 NSMutableArray* maItems = [[NSMutableArray alloc] init];
                 if (nil == _strOwnId)
                 {
                     [maItems addObjectsFromArray:aryPeers];
                 }
                 else
                 {
                     for (NSString* strValue in aryPeers)
                     {
                         if (NSOrderedSame == [_strOwnId caseInsensitiveCompare:strValue])
                         {
                             continue;
                         }
                         
                         [maItems addObject:strValue];
                     }
                 }
                 
                 PeersListViewController* vc = [[PeersListViewController alloc] initWithStyle:UITableViewStylePlain];
                 vc.items = [NSArray arrayWithArray:maItems];
                 vc.callback = self;
                 
                 UINavigationController* nc = [[UINavigationController alloc] initWithRootViewController:vc];
                 
                 dispatch_async(dispatch_get_main_queue(), ^
                                {
                                    [self presentViewController:nc animated:YES completion:nil];
                                });
                 
                 [maItems removeAllObjects];
             }];
        }
        else
        {
            // Closing chat
            [self performSelectorInBackground:@selector(closeCameraConnection) withObject:nil];
        }
    }
}


- (void)callingTo:(NSString *)strDestId
{
    ///選択されたPeer IDに対してData接続を開始する
    SKWConnectOption* option = [[SKWConnectOption alloc] init];
    option.serialization = SKW_SERIALIZATION_NONE;
    option.reliable = YES;
    
    _dataConnection = [_peer connectWithId:strDestId options:option];
    
    NSLog(@"call to %@",strDestId);
    _remoteId = strDestId;
    
    [self setDataCallback:_dataConnection];
}

//
- (void)setDataCallback:(SKWDataConnection *)data
{
    if (nil == data)
    {
        return;
    }

    [data on:SKW_DATACONNECTION_EVENT_OPEN callback:^(NSObject* obj)
     {
         //DataConnectionがオープンされたら@"SSG:stream/start"でIoTデバイス側にビデオストリーム開始の要求
         _bDataConnected = YES;
         
         NSLog(@"DATACONNECTION_EVENT_OPEN");
         [_dataConnection send:@"SSG:stream/start"];
     }];
    
    [data on:SKW_DATACONNECTION_EVENT_DATA callback:^(NSObject* obj)
     {
         NSString* strData = nil;
         
         if ([obj isKindOfClass:[NSString class]])
         {
             strData = (NSString *)obj;
             NSLog(@"DATACONNECTION_EVENT_DATA:%@",strData);
         }
     }];
    
    [data on:SKW_DATACONNECTION_EVENT_CLOSE callback:^(NSObject* obj)
     {
         _bDataConnected = NO;
         [self performSelectorOnMainThread:@selector(closeCameraConnection) withObject:nil waitUntilDone:NO];
     }];
    
    [data on:SKW_DATACONNECTION_EVENT_ERROR callback:^(NSObject* obj)
     {
         SKWPeerError* err = (SKWPeerError *)obj;
         NSString* strMsg = err.message;
         if (nil == strMsg)
         {
             if (nil != err.error)
             {
                 strMsg = err.error.description;
                 NSLog(@"DATACONNECTION_EVENT_ERROR:%@",strMsg);
             }
         }
     }];
}




//sound start用ボタンを押した時に呼ばれる
//voice用のMediaStreamのcallを要求
-(void)touchAudioButton:(NSObject *)sender
{
    if(_bAudioConnected == NO){
        [_dataConnection send:@"SSG:voice/start"];
        [self callWithAudio];
    }else{
        [self closeAudio];
    }
}

-(void)callWithAudio{
    //何秒か待って、AUDIO_相手IDにcallする
    [NSThread sleepForTimeInterval:2.5];
    
    NSString* remoteId = [NSString stringWithFormat:@"AUDIO_%@",_remoteId];
    
    SKWMediaConstraints* constraints = [[SKWMediaConstraints alloc] init];
    constraints.videoFlag = NO;
    constraints.audioFlag = YES;
    
    _msLocal = [SKWNavigator getUserMedia:constraints];
    
    _mediaAudioConnection = [_peer callWithId:remoteId stream:_msLocal];
    [self setMediaCallbacks:_mediaAudioConnection];
}

- (void)setMediaCallbacks:(SKWMediaConnection *)media
{
    if (nil == media)
    {
        return;
    }

    [media on:SKW_MEDIACONNECTION_EVENT_STREAM callback:^(NSObject* obj)
     {
         NSLog(@"SKW_MEDIACONNECTION_EVENT_STREAM");
         // Add Stream;
         if (YES == [obj isKindOfClass:[SKWMediaStream class]] && _bVideoConnected == NO)
         {
             SKWMediaStream* stream = (SKWMediaStream *)obj;
             [self setRemoteView:stream];
             _bVideoConnected = YES;
             NSLog(@"Received Video Stream.");
         }else{
             //音声勝手に繋がるんちゃうかったかな
             _bAudioConnected = YES;
             [self updateActionButtonTitle];
             NSLog(@"Received Audio Stream.");
         }
         
     }];

    [media on:SKW_MEDIACONNECTION_EVENT_CLOSE callback:^(NSObject* obj)
     {
         NSLog(@"SKW_MEDIACONNECTION_EVENT_CLOSE");
     }];

    [media on:SKW_MEDIACONNECTION_EVENT_ERROR callback:^(NSObject* obj)
     {
         NSLog(@"SKW_MEDIACONNECTION_EVENT_ERROR");
     }];

}


-(void)closeAudio
{
    if(_mediaAudioConnection != nil){
        [_mediaAudioConnection on:SKW_MEDIACONNECTION_EVENT_STREAM callback:nil];
        [_mediaAudioConnection on:SKW_MEDIACONNECTION_EVENT_CLOSE callback:nil];
        [_mediaAudioConnection on:SKW_MEDIACONNECTION_EVENT_ERROR callback:nil];
        [_mediaAudioConnection close];
    }
    _mediaAudioConnection = nil;
    _bAudioConnected = NO;
    [self updateActionButtonTitle];
    
}


- (void)closeCameraConnection
{
	if (_mediaVideoConnection != nil )
	{
		if (nil != _msRemote)
		{
			SKWVideo* video = (SKWVideo *)[self.view viewWithTag:TAG_REMOTE_VIDEO];
			if (nil != video)
			{
				[video removeSrc:_msRemote track:0];
			}
			
			[_msRemote close];
			
			_msRemote = nil;
		}
		
        [_mediaVideoConnection on:SKW_MEDIACONNECTION_EVENT_STREAM callback:nil];
        [_mediaVideoConnection on:SKW_MEDIACONNECTION_EVENT_CLOSE callback:nil];
        [_mediaVideoConnection on:SKW_MEDIACONNECTION_EVENT_ERROR callback:nil];
        
		[_mediaVideoConnection close];
	}
    
    if (_dataConnection != nil){
        
        [_dataConnection on:SKW_DATACONNECTION_EVENT_OPEN callback:nil];
        [_dataConnection on:SKW_DATACONNECTION_EVENT_DATA callback:nil];
        [_dataConnection on:SKW_DATACONNECTION_EVENT_CLOSE callback:nil];
        [_dataConnection on:SKW_DATACONNECTION_EVENT_ERROR callback:nil];
        
        [_dataConnection close];
    }
    
    if(_mediaAudioConnection != nil){
        [_mediaAudioConnection on:SKW_MEDIACONNECTION_EVENT_STREAM callback:nil];
        [_mediaAudioConnection on:SKW_MEDIACONNECTION_EVENT_CLOSE callback:nil];
        [_mediaAudioConnection on:SKW_MEDIACONNECTION_EVENT_ERROR callback:nil];
        [_mediaAudioConnection close];
    }
    
    _mediaVideoConnection = nil;
    _mediaAudioConnection = nil;
    _dataConnection = nil;
    _bVideoConnected = NO;
    _bAudioConnected = NO;
    _bDataConnected = NO;
    
    [self updateActionButtonTitle];

}



///Data Connection

- (void)connectDataChannel:(NSString*)destPeerId
{
    // connect option
    SKWConnectOption* option = [[SKWConnectOption alloc] init];
    option.label = @"chat";
    option.metadata = @"{'message': 'hi'}";
    option.serialization = SKW_SERIALIZATION_BINARY;
    option.reliable = YES;
    
    // connect
    _dataConnection = [_peer connectWithId:destPeerId options:option];
    [self setDataCallback:_dataConnection];
}




#pragma mark - Utility

- (void)setRemoteView:(SKWMediaStream *)stream
{
	
	_msRemote = stream;
	
	[self updateActionButtonTitle];
	
	dispatch_async(dispatch_get_main_queue(), ^
				   {
					   SKWVideo* vwRemote = (SKWVideo *)[self.view viewWithTag:TAG_REMOTE_VIDEO];
					   if (nil != vwRemote)
					   {
						   [vwRemote setHidden:NO];
						   [vwRemote setUserInteractionEnabled:YES];
						   
						   [vwRemote addSrc:_msRemote track:0];
					   }
				   });
}

- (void)unsetRemoteView
{
	
	SKWVideo* vwRemote = (SKWVideo *)[self.view viewWithTag:TAG_REMOTE_VIDEO];
	
	if (nil != _msRemote)
	{
		if (nil != vwRemote)
		{
			[vwRemote removeSrc:_msRemote track:0];
		}
		
		[_msRemote close];
		
		_msRemote = nil;
	}
	
	if (nil != vwRemote)
	{
		dispatch_async(dispatch_get_main_queue(), ^
					   {
						   [vwRemote setUserInteractionEnabled:NO];
						   [vwRemote setHidden:YES];
					   });
	}
	
	[self updateActionButtonTitle];
}

- (void)updateActionButtonTitle
{
	dispatch_async(dispatch_get_main_queue(), ^
		{
		   UIButton* btn = (UIButton *)[self.view viewWithTag:TAG_WEBRTC_ACTION];
		   
		   NSString* strTitle = @"Connect";
		   
		   if (NO == _dataConnection)
		   {
			   strTitle = @"Connect";
		   }
		   else
		   {
			   strTitle = @"Disconnect";
		   }
		   
		   [btn setTitle:strTitle forState:UIControlStateNormal];
            
            UIButton* soundButton = (UIButton *)[self.view viewWithTag:TAG_AUDIO_BUTTON];
            NSString* title;
            if(_bAudioConnected == NO)
            {
                title = @"start sound";
            }else
            {
                title = @"end sound";
            }
            
            [soundButton setTitle:title forState:UIControlStateNormal];
            
		});
}


- (void) initializeViews{
    //
    // Initialize views
    //
    CGRect rcScreen = self.view.bounds;
    if (NSFoundationVersionNumber_iOS_6_1 < NSFoundationVersionNumber)
    {
        CGFloat fValue = [UIApplication sharedApplication].statusBarFrame.size.height;
        rcScreen.origin.y = fValue;
        if (nil != self.navigationController)
        {
            if (NO == self.navigationController.navigationBarHidden)
            {
                fValue = self.navigationController.navigationBar.frame.size.height;
                rcScreen.origin.y += fValue;
            }
        }
    }
    
    // Initialize Remote video view
    CGRect rcRemote = CGRectZero;
    if (UIUserInterfaceIdiomPad == [UIDevice currentDevice].userInterfaceIdiom)
    {
        // iPad
        rcRemote.size.width = 480.0f;
        rcRemote.size.height = 480.0f;
    }
    else
    {
        // iPhone / iPod touch
        rcRemote.size.width = rcScreen.size.width;
        rcRemote.size.height = rcRemote.size.width;
    }
    rcRemote.origin.x = (rcScreen.size.width - rcRemote.size.width) / 2.0f;
    rcRemote.origin.y = (rcScreen.size.height - rcRemote.size.height) / 2.0f;
    rcRemote.origin.y -= 8.0f;
    
    
    //Remote Video View
    SKWVideo* vwRemote = [[SKWVideo alloc] initWithFrame:rcRemote];
    [vwRemote setTag:TAG_REMOTE_VIDEO];
    [vwRemote setUserInteractionEnabled:NO];
    [vwRemote setHidden:YES];
    [self.view addSubview:vwRemote];
    
    
    // Peer ID View
    UIFont* fnt = [UIFont systemFontOfSize:[UIFont labelFontSize]];
    
    CGRect rcId = rcScreen;
    rcId.size.width = (rcScreen.size.width / 3.0f) * 2.0f;
    rcId.size.height = fnt.lineHeight * 2.0f;
    
    UILabel* lblId = [[UILabel alloc] initWithFrame:rcId];
    [lblId setTag:TAG_ID];
    [lblId setFont:fnt];
    [lblId setTextAlignment:NSTextAlignmentCenter];
    lblId.numberOfLines = 2;
    [lblId setText:@"your ID:\n ---"];
    [lblId setBackgroundColor:[UIColor whiteColor]];
    
    [self.view addSubview:lblId];
    
    // Call Button
    CGRect rcCall = rcId;
    rcCall.origin.x	= rcId.origin.x + rcId.size.width;
    rcCall.size.width = (rcScreen.size.width / 3.0f) * 1.0f;
    rcCall.size.height = fnt.lineHeight * 2.0f;
    UIButton* btnCall = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [btnCall setTag:TAG_WEBRTC_ACTION];
    [btnCall setFrame:rcCall];
    [btnCall setTitle:@"Call to" forState:UIControlStateNormal];
    [btnCall setBackgroundColor:[UIColor lightGrayColor]];
    [btnCall addTarget:self action:@selector(onTouchCallButton:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:btnCall];
    
    
    //Send Audio Stream Button
    CGRect rcBtnAudio = rcScreen;
    rcBtnAudio.size.width = rcScreen.size.width;
    rcBtnAudio.size.height = fnt.lineHeight * 2.0f + 20;
    rcBtnAudio.origin.y = rcScreen.size.height - rcBtnAudio.size.height;
    
    UIButton* btnSendAudio = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [btnSendAudio setTag:TAG_AUDIO_BUTTON];
    [btnSendAudio setFrame:rcBtnAudio];
    [btnSendAudio setTitle:@"send SSG:stream/start" forState:UIControlStateNormal];
    [btnSendAudio setBackgroundColor:[UIColor lightGrayColor]];
    [btnSendAudio addTarget:self action:@selector(touchAudioButton:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:btnSendAudio];

}




#pragma mark - Lifecycle

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
    [self updateActionButtonTitle];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    
    [super viewDidDisappear:animated];
}

- (void)dealloc
{
    _msLocal = nil;
    _msRemote = nil;
    
    _strOwnId = nil;
    
    _mediaVideoConnection = nil;
    _peer = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
