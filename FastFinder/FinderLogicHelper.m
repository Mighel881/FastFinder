//
//  FinderLogicHelper.m
//  FastFinder
//
//  Created by Anthonin Cocagne on 30/11/2018.
//  Copyright © 2018 Anthonin Cocagne. All rights reserved.
//

#import "FinderLogicHelper.h"

#import <ScriptingBridge/ScriptingBridge.h>
#import "Finder.h"
#import "SystemEvents.h"

#import "UserSettingsHelper.h"

//CONFIGURATION

//for first launch
static CGFloat const DEFAULT_FINDER_HEIGHT = 500;
//static CGFloat const DEFAULT_FINDER_WIDTH = 1440;


@implementation FinderLogicHelper {
    CGFloat screenHeight;
    CGFloat screenWidth;

    NSInteger idOfVisorFinderWindow;
    CGFloat lastFinderHeight;
}


static FinderLogicHelper *instance = nil;

+(FinderLogicHelper*)getInstance {
    @synchronized(self) {
        if(instance==nil) {
            instance = [FinderLogicHelper new];
            
            //defaults values
            CGRect screenRect = [[NSScreen mainScreen] frame];
            instance->screenWidth = screenRect.size.width;
            instance->screenHeight = screenRect.size.height;
        }
    }
    return instance;
}

-(void) processFinderLogic {
    // this is the finder
    FinderApplication * finder = [SBApplication applicationWithBundleIdentifier:@"com.apple.Finder"];
    //    finder.launchFlags = kLSLaunchAndHide;
//    SystemEventsApplication * systEvt = [SBApplication applicationWithBundleIdentifier:@"com.apple.SystemEvents"]; //pour envoyer des shortcuts à l'app https://github.com/tcurdt/shellhere/blob/master/main.m#L114
    
    
    NSLog(@"Frontmost : %hhd | Visible : %hhd", finder.frontmost, finder.visible);
    
    [self show:!finder.frontmost finder:finder];
}


-(void) show:(BOOL)show finder:(FinderApplication*)finder {
    SBElementArray * finderWindows = finder.FinderWindows;
    FinderWindow *finderWindow;
    
    CGFloat finderHeight = finderWindow.bounds.size.height;
//    NSLog(@"finderHeight : %f", finderHeight);
    
    BOOL animated = [UserSettingsHelper getInstance].animated;
    
    
    if (show) {
        NSLog(@"Show finder");
        //                [finder activate];
        [self runCommand:@"open -j -a Finder"]; //activate without moving window when it outside of screen
        finder.visible = YES;

        finderWindow = [self getFinderWindowFromWindows:finderWindows]; //it should be done after finder.visible = YES
        
        //set size
        if (lastFinderHeight == 0) {
            lastFinderHeight = DEFAULT_FINDER_HEIGHT;
            [finderWindow setBounds:NSMakeRect(0, screenHeight, screenWidth, lastFinderHeight)]; //on set les bounds suivants : {toutAGaucheDeLecran, enDehorsDeLecranEnBas_pourEtreInvisible, tailleEcran, lastFinderHeight)}
        }
        
        if (animated) {
            [self animateOffsetWindow:finderWindow directionUp:YES completionHandler:nil];
        }
    } else {
        NSLog(@"Hide finder");
        
        finderWindow = [self getFinderWindowFromWindows:finderWindows];

        if (finderHeight != 0) {
            lastFinderHeight = finderHeight;
        }
        
        if (animated) {
            [self animateOffsetWindow:finderWindow directionUp:NO completionHandler:^{
                //si la frontmost window au moment de faire le raccourci prend tout l'ecran (window.bounds == screen.bounds)
                finder.visible = NO; //c'est ceci qui cause le glitch qui est visible quand il n'y a pas d'autre fenetre derriere, car quand on réactive le finder après l'avoir hidden, il restaure position
                
                //si la frontmost window au moment de faire le raccourci NE prend PAS tout l'ecran (window.bounds == screen.bounds), mais le probleme de cette version, c'est que le fait de ne pas visible=NO le finder, fait que si on clique sur l'icone manuellement, il reste à sa position…
//                finder.frontmost = NO;
////                finder.visible = NO;
//                [finderWindow setPosition:NSMakePoint(-1440, 900)];
            }];
        } else {
            finder.visible = NO;
        }
    }
}

-(FinderWindow*) getFinderWindowFromWindows:(SBElementArray*)finderWindows {
    FinderWindow *finderWindow = nil;

    if (finderWindows.count > 1) {
        for (FinderWindow *finderWin in finderWindows) {
            //            NSLog(@"win : %@", finderWin.properties); //this can cause glitch…
            
            if (finderWin.id == idOfVisorFinderWindow) {
                finderWindow = finderWin;
                finderWindow.index = 1; //setting this window the frontmost one
            }
        }
        
        //don't really know why i have to do this a second time, but without this it doesn't work
        if (finderWindow.id != idOfVisorFinderWindow) {
            NSLog(@"Window isn't the good one, searching for the good one…");
            for (FinderWindow *finderWin in finderWindows) {
                if (finderWin.id == idOfVisorFinderWindow) {
                    finderWindow = finderWin;
                }
            }
        }
    }
    
    if (finderWindow == nil) {
        NSLog(@"Window not found, taking the frontmost one");
        finderWindow = finderWindows[0];
    }
    
//    NSLog(@"Window : id:%ld, name:%@, index:%ld, idOfVisorFinderWindow:%ld", finderWindow.id, finderWindow.name, finderWindow.index, idOfVisorFinderWindow);
    
    idOfVisorFinderWindow = finderWindow.id;
    return finderWindow;
}


- (void)animateOffsetWindow:(FinderWindow *)finderWindow directionUp:(BOOL)directionUp completionHandler:(void (^)(void))completionHandler { //direction YES is UP (show)
    NSTimeInterval t;
    NSDate* date = [NSDate date];
    float animationSpeed = [UserSettingsHelper getInstance].animationVelocity;
    
    while (animationSpeed >= (t = -[date timeIntervalSinceNow])) {
        float k = t / animationSpeed; //k varie de 0 à 1
        float kAccordingToDirection = directionUp ? 1 - k : k;
        
//        NSLog(@"kAccordingToDirection = %f", kAccordingToDirection);
        
        float offset = kAccordingToDirection * lastFinderHeight + (screenHeight - lastFinderHeight);
//            NSLog(@"offset = %f", offset);
        [finderWindow setPosition:NSMakePoint(0, offset)];
        
        //            usleep(_background ? 1000 : 5000);         // 1 or 5ms
        usleep(3000);
    }
    
    //un dernier coup pour être sur d'être au bon endroit (au final ça ne fonctionne que pour SHOW car quand le finder est en bas, MacOS n'autorise pas sa frame d'aller plus bas que sa status bar)
    float kAccordingToDirection = directionUp ? 0 : 1;
    float offset = kAccordingToDirection * lastFinderHeight + (screenHeight - lastFinderHeight);
    NSLog(@"offset = %f", offset);
    [finderWindow setPosition:NSMakePoint(0, offset)];
    
    
    if (completionHandler)
        completionHandler();
}




#pragma mark - Misc

- (NSString *)runCommand:(NSString *)commandToRun {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/sh"];
    
    NSArray *arguments = [NSArray arrayWithObjects:
                          @"-c" ,
                          [NSString stringWithFormat:@"%@", commandToRun],
                          nil];
    NSLog(@"run command:%@", commandToRun);
    [task setArguments:arguments];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    
    NSFileHandle *file = [pipe fileHandleForReading];
    
    [task launch];
    
    NSData *data = [file readDataToEndOfFile];
    
    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return output;
}

@end
