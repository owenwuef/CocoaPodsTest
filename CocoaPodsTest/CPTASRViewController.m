//
//  CPTASRViewController.m
//  CocoaPodsTest
//
//  Created by OwenWu on 14/10/14.
//  Copyright (c) 2014 OwenWu. All rights reserved.
//

#import "CPTASRViewController.h"
#import "PureLayout.h"

#import <OpenEars/PocketsphinxController.h> // Please note that unlike in previous versions of OpenEars, we now link the headers through the framework.
#import <OpenEars/LanguageModelGenerator.h>
#import <OpenEars/OpenEarsLogging.h>
#import <OpenEars/AcousticModel.h>

typedef NS_ENUM(NSInteger, ExampleConstraintDemo) {
    ExampleConstraintDemoReset = 0,
    ExampleConstraintDemo1,
    ExampleConstraintDemo2,
    ExampleConstraintDemo3,
    ExampleConstraintDemo4,
    ExampleConstraintDemo5,
    ExampleConstraintDemo6,
    ExampleConstraintDemoCount
};

@interface CPTASRViewController ()

@property (nonatomic, strong) UIView *containerView;

@property (nonatomic, strong) UITextView *textViewAbove;
@property (nonatomic, strong) UITextView *textViewBelow;

@property (nonatomic, strong) UILabel *labelInputLevel;
@property (nonatomic, strong) UILabel *labelOutputLevel;

@property (nonatomic, strong) UIButton *buttonStartListening;
@property (nonatomic, strong) UIButton *buttonStopListening;
@property (nonatomic, strong) UIButton *buttonSuspendRecognition;
@property (nonatomic, strong) UIButton *buttonResumeRecognition;

@end

@implementation CPTASRViewController

@synthesize pocketsphinxController, uiUpdateTimer;
@synthesize openEarsEventsObserver;
@synthesize usingStartLanguageModel;
@synthesize pathToFirstDynamicallyGeneratedLanguageModel;
@synthesize pathToFirstDynamicallyGeneratedDictionary;
@synthesize pathToSecondDynamicallyGeneratedLanguageModel;
@synthesize pathToSecondDynamicallyGeneratedDictionary;
@synthesize restartAttemptsDueToPermissionRequests;
@synthesize startupFailedDueToLackOfPermissions;

#define kLevelUpdatesPerSecond 18 // We'll have the ui update 18 times a second to show some fluidity without hitting the CPU too hard.

//#define kGetNbest // Uncomment this if you want to try out nbest
#pragma mark -
#pragma mark Memory Management

- (void)dealloc {
    [self stopDisplayingLevels]; // We'll need to stop any running timers before attempting to deallocate here.
    openEarsEventsObserver.delegate = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self viewdidLoadLikeOpenEars];
    
    [self setupViews];
    
    [self.view setNeedsUpdateConstraints];
}

- (void)viewdidLoadLikeOpenEars {
    self.restartAttemptsDueToPermissionRequests = 0;
    self.startupFailedDueToLackOfPermissions = FALSE;
    
    //[OpenEarsLogging startOpenEarsLogging]; // Uncomment me for OpenEarsLogging
    
    [self.openEarsEventsObserver setDelegate:self]; // Make this class the delegate of OpenEarsObserver so we can get all of the messages about what OpenEars is doing.
    
    
    
    // This is the language model we're going to start up with. The only reason I'm making it a class property is that I reuse it a bunch of times in this example,
    // but you can pass the string contents directly to PocketsphinxController:startListeningWithLanguageModelAtPath:dictionaryAtPath:languageModelIsJSGF:
    
    NSArray *firstLanguageArray = [[NSArray alloc] initWithArray:[NSArray arrayWithObjects: // All capital letters.
                                                                  @"BACKWARD",
                                                                  @"CHANGE",
                                                                  @"FORWARD",
                                                                  @"GO",
                                                                  @"LEFT",
                                                                  @"MODEL",
                                                                  @"RIGHT",
                                                                  @"TURN",
                                                                  nil]];
    
    LanguageModelGenerator *languageModelGenerator = [[LanguageModelGenerator alloc] init];
    
    NSError *error = [languageModelGenerator generateLanguageModelFromArray:firstLanguageArray withFilesNamed:@"FirstOpenEarsDynamicLanguageModel" forAcousticModelAtPath:[AcousticModel pathToModel:@"AcousticModelEnglish"]]; // Change "AcousticModelEnglish" to "AcousticModelSpanish" in order to create a language model for Spanish recognition instead of English.
    
    NSDictionary *firstDynamicLanguageGenerationResultsDictionary = nil;
    if([error code] != noErr) {
        NSLog(@"Dynamic language generator reported error %@", [error description]);
    } else {
        firstDynamicLanguageGenerationResultsDictionary = [error userInfo];
        
        NSString *lmFile = [firstDynamicLanguageGenerationResultsDictionary objectForKey:@"LMFile"];
        NSString *dictionaryFile = [firstDynamicLanguageGenerationResultsDictionary objectForKey:@"DictionaryFile"];
        NSString *lmPath = [firstDynamicLanguageGenerationResultsDictionary objectForKey:@"LMPath"];
        NSString *dictionaryPath = [firstDynamicLanguageGenerationResultsDictionary objectForKey:@"DictionaryPath"];
        
        NSLog(@"Dynamic language generator completed successfully, you can find your new files %@\n and \n%@\n at the paths \n%@ \nand \n%@", lmFile,dictionaryFile,lmPath,dictionaryPath);
        
        self.pathToFirstDynamicallyGeneratedLanguageModel = lmPath;
        self.pathToFirstDynamicallyGeneratedDictionary = dictionaryPath;
    }
    
    self.usingStartLanguageModel = TRUE; // This is not an OpenEars thing, this is just so I can switch back and forth between the two models in this sample app.
    
    // Here is an example of dynamically creating an in-app grammar.
    
    // We want it to be able to response to the speech "CHANGE MODEL" and a few other things.  Items we want to have recognized as a whole phrase (like "CHANGE MODEL")
    // we put into the array as one string (e.g. "CHANGE MODEL" instead of "CHANGE" and "MODEL"). This increases the probability that they will be recognized as a phrase. This works even better starting with version 1.0 of OpenEars.
    
    NSArray *secondLanguageArray = [[NSArray alloc] initWithArray:[NSArray arrayWithObjects: // All capital letters.
                                                                   @"SUNDAY",
                                                                   @"MONDAY",
                                                                   @"TUESDAY",
                                                                   @"WEDNESDAY",
                                                                   @"THURSDAY",
                                                                   @"FRIDAY",
                                                                   @"SATURDAY",
                                                                   @"QUIDNUNC",
                                                                   @"CHANGE MODEL",
                                                                   nil]];
    
    // The last entry, quidnunc, is an example of a word which will not be found in the lookup dictionary and will be passed to the fallback method. The fallback method is slower,
    // so, for instance, creating a new language model from dictionary words will be pretty fast, but a model that has a lot of unusual names in it or invented/rare/recent-slang
    // words will be slower to generate. You can use this information to give your users good UI feedback about what the expectations for wait times should be.
    
    // I don't think it's beneficial to lazily instantiate LanguageModelGenerator because you only need to give it a single message and then release it.
    // If you need to create a very large model or any size of model that has many unusual words that have to make use of the fallback generation method,
    // you will want to run this on a background thread so you can give the user some UI feedback that the task is in progress.
    
    //    languageModelGenerator.verboseLanguageModelGenerator = TRUE; // Uncomment me for verbose debug output
    
    // generateLanguageModelFromArray:withFilesNamed returns an NSError which will either have a value of noErr if everything went fine or a specific error if it didn't.
    error = [languageModelGenerator generateLanguageModelFromArray:secondLanguageArray withFilesNamed:@"SecondOpenEarsDynamicLanguageModel" forAcousticModelAtPath:[AcousticModel pathToModel:@"AcousticModelEnglish"]]; // Change "AcousticModelEnglish" to "AcousticModelSpanish" in order to create a language model for Spanish recognition instead of English.
    
    //    NSError *error = [languageModelGenerator generateLanguageModelFromTextFile:[NSString stringWithFormat:@"%@/%@",[[NSBundle mainBundle] resourcePath], @"OpenEarsCorpus.txt"] withFilesNamed:@"SecondOpenEarsDynamicLanguageModel" forAcousticModelAtPath:[AcousticModel pathToModel:@"AcousticModelEnglish"]]; // Try this out to see how generating a language model from a corpus works.
    
    
    
    NSDictionary *secondDynamicLanguageGenerationResultsDictionary = nil;
    if([error code] != noErr) {
        NSLog(@"Dynamic language generator reported error %@", [error description]);
    } else {
        secondDynamicLanguageGenerationResultsDictionary = [error userInfo];
        
        // A useful feature of the fact that generateLanguageModelFromArray:withFilesNamed: always returns an NSError is that when it returns noErr (meaning there was
        // no error, or an [NSError code] of zero), the NSError also contains a userInfo dictionary which contains the path locations of your new files.
        
        // What follows demonstrates how to get the paths for your created dynamic language models out of that userInfo dictionary.
        NSString *lmFile = [secondDynamicLanguageGenerationResultsDictionary objectForKey:@"LMFile"];
        NSString *dictionaryFile = [secondDynamicLanguageGenerationResultsDictionary objectForKey:@"DictionaryFile"];
        NSString *lmPath = [secondDynamicLanguageGenerationResultsDictionary objectForKey:@"LMPath"];
        NSString *dictionaryPath = [secondDynamicLanguageGenerationResultsDictionary objectForKey:@"DictionaryPath"];
        
        NSLog(@"Dynamic language generator completed successfully, you can find your new files %@\n and \n%@\n at the paths \n%@ \nand \n%@", lmFile,dictionaryFile,lmPath,dictionaryPath);
        
        // pathToDynamicallyGeneratedGrammar/Dictionary aren't OpenEars things, they are just the way I'm controlling being able to switch between the grammars in this sample app.
        self.pathToSecondDynamicallyGeneratedLanguageModel = lmPath; // We'll set our new .languagemodel file to be the one to get switched to when the words "CHANGE MODEL" are recognized.
        self.pathToSecondDynamicallyGeneratedDictionary = dictionaryPath; // We'll set our new dictionary to be the one to get switched to when the words "CHANGE MODEL" are recognized.
    }
    
    
    // Next, an informative message.
    
    NSLog(@"\n\nWelcome to the OpenEars sample project. This project understands the words:\nBACKWARD,\nCHANGE,\nFORWARD,\nGO,\nLEFT,\nMODEL,\nRIGHT,\nTURN,\nand if you say \"CHANGE MODEL\" it will switch to its dynamically-generated model which understands the words:\nCHANGE,\nMODEL,\nMONDAY,\nTUESDAY,\nWEDNESDAY,\nTHURSDAY,\nFRIDAY,\nSATURDAY,\nSUNDAY,\nQUIDNUNC");
    
    // This is how to start the continuous listening loop of an available instance of PocketsphinxController. We won't do this if the language generation failed since it will be listening for a command to change over to the generated language.
    if(secondDynamicLanguageGenerationResultsDictionary) {
        
        [self startListening];
        
    }
    
    // [self startDisplayingLevels] is not an OpenEars method, just an approach for level reading
    // that I've included with this sample app. My example implementation does make use of two OpenEars
    // methods:	the pocketsphinxInputLevel method of PocketsphinxController and the fliteOutputLevel
    // method of fliteController.
    //
    // The example is meant to show one way that you can read those levels continuously without locking the UI,
    // by using an NSTimer, but the OpenEars level-reading methods
    // themselves do not include multithreading code since I believe that you will want to design your own
    // code approaches for level display that are tightly-integrated with your interaction design and the
    // graphics API you choose.
    //
    // Please note that if you use my sample approach, you should pay attention to the way that the timer is always stopped in
    // dealloc. This should prevent you from having any difficulties with deallocating a class due to a running NSTimer process.
    
    [self startDisplayingLevels];
    
    // Here is some UI stuff that has nothing specifically to do with OpenEars implementation
    self.buttonStartListening.hidden = TRUE;
    self.buttonStopListening.hidden = TRUE;
    self.buttonSuspendRecognition.hidden = TRUE;
    self.buttonResumeRecognition.hidden = TRUE;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

// Should be called only once
- (void)setupViews
{
    _containerView = [UIView newAutoLayoutView];
    _containerView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    [self.view addSubview:self.containerView];

    _textViewAbove = [[UITextView alloc] initForAutoLayout];
    _textViewAbove.backgroundColor = [UIColor grayColor];
    _textViewAbove.userInteractionEnabled = NO;

    _textViewBelow = [[UITextView alloc] initForAutoLayout];
    _textViewBelow.backgroundColor = [UIColor grayColor];
    _textViewBelow.userInteractionEnabled = NO;

    _labelInputLevel = [[UILabel alloc] initForAutoLayout];
    _labelInputLevel.backgroundColor = [UIColor whiteColor];
    _labelInputLevel.adjustsFontSizeToFitWidth = YES;
    
    _labelOutputLevel = [[UILabel alloc] initForAutoLayout];
    _labelOutputLevel.backgroundColor = [UIColor whiteColor];
    
    _buttonStartListening = [[UIButton alloc] initForAutoLayout];
    _buttonStartListening.backgroundColor = [UIColor blueColor];
    [_buttonStartListening addTarget:self action:@selector(startButtonAction) forControlEvents:UIControlEventTouchUpInside];
    [_buttonStartListening setTitle:@"Start" forState:UIControlStateNormal];

    _buttonStopListening = [[UIButton alloc] initForAutoLayout];
    _buttonStopListening.backgroundColor = [UIColor blueColor];
    [_buttonStopListening addTarget:self action:@selector(stopButtonAction) forControlEvents:UIControlEventTouchUpInside];
    [_buttonStopListening setTitle:@"Stop" forState:UIControlStateNormal];
    
    _buttonSuspendRecognition = [[UIButton alloc] initForAutoLayout];
    _buttonSuspendRecognition.backgroundColor = [UIColor blueColor];
    [_buttonSuspendRecognition addTarget:self action:@selector(suspendListeningButtonAction) forControlEvents:UIControlEventTouchUpInside];
    [_buttonSuspendRecognition setTitle:@"Suspend Recognition" forState:UIControlStateNormal];
    
    _buttonResumeRecognition = [[UIButton alloc] initForAutoLayout];
    _buttonResumeRecognition.backgroundColor = [UIColor blueColor];
    [_buttonResumeRecognition addTarget:self action:@selector(resumeListeningButtonAction) forControlEvents:UIControlEventTouchUpInside];
    [_buttonResumeRecognition setTitle:@"Resume Recognition" forState:UIControlStateNormal];

    [self.containerView addSubview:self.textViewAbove];
    [self.containerView addSubview:self.textViewBelow];
    [self.containerView addSubview:self.labelInputLevel];
    [self.containerView addSubview:self.labelOutputLevel];
    [self.containerView addSubview:self.buttonStartListening];
    [self.containerView addSubview:self.buttonStopListening];
    [self.containerView addSubview:self.buttonSuspendRecognition];
    [self.containerView addSubview:self.buttonResumeRecognition];
}

- (void)updateViewConstraints
{
    [super updateViewConstraints];
    
    [self stopAllAnimationsForViewAndSubviews:self.containerView];
    
    // WARNING: Be sure to read the documentation on the below method - it can cause major performance issues!
    // It is only used here as a convenience for demonstration purposes only.
    [self.containerView autoRemoveConstraintsAffectingViewAndSubviews];
    
    [self.containerView autoPinToTopLayoutGuideOfViewController:self withInset:10.0f];
    [self.containerView autoPinToBottomLayoutGuideOfViewController:self withInset:10.0f];
    [self.containerView autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:10.0f];
    [self.containerView autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:10.0f];
    
    [self setupDemo1];
}

/**
 Demonstrates:
 - Setting a view to a fixed width
 - Matching the widths of subviews
 - Distributing subviews vertically with a fixed height
 */
- (void)setupDemo1
{
    NSArray *subviews = @[self.textViewAbove, self.textViewBelow, self.labelInputLevel, self.labelOutputLevel, self.buttonStartListening, self.buttonStopListening, self.buttonSuspendRecognition, self.buttonResumeRecognition];
    
    [self.textViewAbove autoSetDimension:ALDimensionWidth toSize:250.0f];
    [subviews autoMatchViewsDimension:ALDimensionWidth];
    
    [self.buttonSuspendRecognition autoAlignAxisToSuperviewAxis:ALAxisVertical];
    [subviews autoDistributeViewsAlongAxis:ALAxisVertical withFixedSize:60.0f insetSpacing:YES alignment:NSLayoutFormatAlignAllCenterX];
}

- (void)stopAllAnimationsForViewAndSubviews:(UIView *)view
{
    [view.layer removeAllAnimations];
    for (UIView *subview in view.subviews) {
        [self stopAllAnimationsForViewAndSubviews:subview];
    }
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

#pragma mark -
#pragma mark Lazy Allocation

// Lazily allocated PocketsphinxController.
- (PocketsphinxController *)pocketsphinxController {
    if (pocketsphinxController == nil) {
        pocketsphinxController = [[PocketsphinxController alloc] init];
        //pocketsphinxController.verbosePocketSphinx = TRUE; // Uncomment me for verbose debug output
        pocketsphinxController.outputAudio = TRUE;
#ifdef kGetNbest
        pocketsphinxController.returnNbest = TRUE;
        pocketsphinxController.nBestNumber = 5;
#endif
    }
    return pocketsphinxController;
}

// Lazily allocated OpenEarsEventsObserver.
- (OpenEarsEventsObserver *)openEarsEventsObserver {
    if (openEarsEventsObserver == nil) {
        openEarsEventsObserver = [[OpenEarsEventsObserver alloc] init];
    }
    return openEarsEventsObserver;
}

// The last class we're using here is LanguageModelGenerator but I don't think it's advantageous to lazily instantiate it. You can see how it's used below.

- (void) startListening {
    
    // startListeningWithLanguageModelAtPath:dictionaryAtPath:languageModelIsJSGF always needs to know the grammar file being used,
    // the dictionary file being used, and whether the grammar is a JSGF. You must put in the correct value for languageModelIsJSGF.
    // Inside of a single recognition loop, you can only use JSGF grammars or ARPA grammars, you can't switch between the two types.
    
    // An ARPA grammar is the kind with a .languagemodel or .DMP file, and a JSGF grammar is the kind with a .gram file.
    
    // If you wanted to just perform recognition on an isolated wav file for testing, you could do it as follows:
    
    // NSString *wavPath = [NSString stringWithFormat:@"%@/%@",[[NSBundle mainBundle] resourcePath], @"test.wav"];
    //[self.pocketsphinxController runRecognitionOnWavFileAtPath:wavPath usingLanguageModelAtPath:self.pathToGrammarToStartAppWith dictionaryAtPath:self.pathToDictionaryToStartAppWith languageModelIsJSGF:FALSE];  // Starts the recognition loop.
    
    // But under normal circumstances you'll probably want to do continuous recognition as follows:
    
    [self.pocketsphinxController startListeningWithLanguageModelAtPath:self.pathToFirstDynamicallyGeneratedLanguageModel
                                                      dictionaryAtPath:self.pathToFirstDynamicallyGeneratedDictionary
                                                   acousticModelAtPath:[AcousticModel pathToModel:@"AcousticModelEnglish"]
                                                   languageModelIsJSGF:FALSE]; // Change "AcousticModelEnglish" to "AcousticModelSpanish" in order to perform Spanish recognition instead of English.
    
}

#pragma mark -
#pragma mark OpenEarsEventsObserver delegate methods

// What follows are all of the delegate methods you can optionally use once you've instantiated an OpenEarsEventsObserver and set its delegate to self.
// I've provided some pretty granular information about the exact phase of the Pocketsphinx listening loop, the Audio Session, and Flite, but I'd expect
// that the ones that will really be needed by most projects are the following:
//
//- (void) pocketsphinxDidReceiveHypothesis:(NSString *)hypothesis recognitionScore:(NSString *)recognitionScore utteranceID:(NSString *)utteranceID;
//- (void) audioSessionInterruptionDidBegin;
//- (void) audioSessionInterruptionDidEnd;
//- (void) audioRouteDidChangeToRoute:(NSString *)newRoute;
//- (void) pocketsphinxDidStartListening;
//- (void) pocketsphinxDidStopListening;
//
// It isn't necessary to have a PocketsphinxController or a FliteController instantiated in order to use these methods.  If there isn't anything instantiated that will
// send messages to an OpenEarsEventsObserver, all that will happen is that these methods will never fire.  You also do not have to create a OpenEarsEventsObserver in
// the same class or view controller in which you are doing things with a PocketsphinxController or FliteController; you can receive updates from those objects in
// any class in which you instantiate an OpenEarsEventsObserver and set its delegate to self.

// An optional delegate method of OpenEarsEventsObserver which delivers the text of speech that Pocketsphinx heard and analyzed, along with its accuracy score and utterance ID.
- (void) pocketsphinxDidReceiveHypothesis:(NSString *)hypothesis recognitionScore:(NSString *)recognitionScore utteranceID:(NSString *)utteranceID {
    
    NSLog(@"The received hypothesis is %@ with a score of %@ and an ID of %@", hypothesis, recognitionScore, utteranceID); // Log it.
    if([hypothesis isEqualToString:@"CHANGE MODEL"]) { // If the user says "CHANGE MODEL", we will switch to the alternate model (which happens to be the dynamically generated model).
        
        // Here is an example of language model switching in OpenEars. Deciding on what logical basis to switch models is your responsibility.
        // For instance, when you call a customer service line and get a response tree that takes you through different options depending on what you say to it,
        // the models are being switched as you progress through it so that only relevant choices can be understood. The construction of that logical branching and
        // how to react to it is your job, OpenEars just lets you send the signal to switch the language model when you've decided it's the right time to do so.
        
        if(self.usingStartLanguageModel == TRUE) { // If we're on the starting model, switch to the dynamically generated one.
            
            // You can only change language models with ARPA grammars in OpenEars (the ones that end in .languagemodel or .DMP).
            // Trying to switch between JSGF models (the ones that end in .gram) will return no result.
            [self.pocketsphinxController changeLanguageModelToFile:self.pathToSecondDynamicallyGeneratedLanguageModel withDictionary:self.pathToSecondDynamicallyGeneratedDictionary];
            self.usingStartLanguageModel = FALSE;
        } else { // If we're on the dynamically generated model, switch to the start model (this is just an example of a trigger and method for switching models).
            [self.pocketsphinxController changeLanguageModelToFile:self.pathToFirstDynamicallyGeneratedLanguageModel withDictionary:self.pathToFirstDynamicallyGeneratedDictionary];
            self.usingStartLanguageModel = TRUE;
        }
    }
    
    self.textViewAbove.text = [NSString stringWithFormat:@"Heard: \"%@\"", hypothesis]; // Show it in the status box.
    
    // This is how to use an available instance of FliteController. We're going to repeat back the command that we heard with the voice we've chosen.
//    [self.fliteController say:[NSString stringWithFormat:@"You said %@",hypothesis] withVoice:self.slt];
}

#ifdef kGetNbest
- (void) pocketsphinxDidReceiveNBestHypothesisArray:(NSArray *)hypothesisArray { // Pocketsphinx has an n-best hypothesis dictionary.
    NSLog(@"hypothesisArray is %@",hypothesisArray);
}
#endif
// An optional delegate method of OpenEarsEventsObserver which informs that there was an interruption to the audio session (e.g. an incoming phone call).
- (void) audioSessionInterruptionDidBegin {
    NSLog(@"AudioSession interruption began."); // Log it.
    self.textViewBelow.text = @"Status: AudioSession interruption began."; // Show it in the status box.
    [self.pocketsphinxController stopListening]; // React to it by telling Pocketsphinx to stop listening since it will need to restart its loop after an interruption.
}

// An optional delegate method of OpenEarsEventsObserver which informs that the interruption to the audio session ended.
- (void) audioSessionInterruptionDidEnd {
    NSLog(@"AudioSession interruption ended."); // Log it.
    self.textViewBelow.text = @"Status: AudioSession interruption ended."; // Show it in the status box.
    // We're restarting the previously-stopped listening loop.
    [self startListening];
    
}

// An optional delegate method of OpenEarsEventsObserver which informs that the audio input became unavailable.
- (void) audioInputDidBecomeUnavailable {
    NSLog(@"The audio input has become unavailable"); // Log it.
    self.textViewBelow.text = @"Status: The audio input has become unavailable"; // Show it in the status box.
    [self.pocketsphinxController stopListening]; // React to it by telling Pocketsphinx to stop listening since there is no available input
}

// An optional delegate method of OpenEarsEventsObserver which informs that the unavailable audio input became available again.
- (void) audioInputDidBecomeAvailable {
    NSLog(@"The audio input is available"); // Log it.
    self.textViewBelow.text = @"Status: The audio input is available"; // Show it in the status box.
    [self startListening];
}

// An optional delegate method of OpenEarsEventsObserver which informs that there was a change to the audio route (e.g. headphones were plugged in or unplugged).
- (void) audioRouteDidChangeToRoute:(NSString *)newRoute {
    NSLog(@"Audio route change. The new audio route is %@", newRoute); // Log it.
    self.textViewBelow.text = [NSString stringWithFormat:@"Status: Audio route change. The new audio route is %@",newRoute]; // Show it in the status box.
    
    [self.pocketsphinxController stopListening]; // React to it by telling the Pocketsphinx loop to shut down and then start listening again on the new route
    [self startListening];
}

// An optional delegate method of OpenEarsEventsObserver which informs that the Pocketsphinx recognition loop hit the calibration stage in its startup.
// This might be useful in debugging a conflict between another sound class and Pocketsphinx. Another good reason to know when you're in the middle of
// calibration is that it is a timeframe in which you want to avoid playing any other sounds including speech so the calibration will be successful.
- (void) pocketsphinxDidStartCalibration {
    NSLog(@"Pocketsphinx calibration has started."); // Log it.
    self.textViewBelow.text = @"Status: Pocketsphinx calibration has started."; // Show it in the status box.
}

// An optional delegate method of OpenEarsEventsObserver which informs that the Pocketsphinx recognition loop completed the calibration stage in its startup.
// This might be useful in debugging a conflict between another sound class and Pocketsphinx.
- (void) pocketsphinxDidCompleteCalibration {
    NSLog(@"Pocketsphinx calibration is complete."); // Log it.
    self.textViewBelow.text = @"Status: Pocketsphinx calibration is complete."; // Show it in the status box.
    
//    self.fliteController.duration_stretch = .9; // Change the speed
//    self.fliteController.target_mean = 1.2; // Change the pitch
//    self.fliteController.target_stddev = 1.5; // Change the variance
//    
//    [self.fliteController say:@"Welcome to OpenEars." withVoice:self.slt];
//    // The same statement with the pitch and other voice values changed.
//    
//    self.fliteController.duration_stretch = 1.0; // Reset the speed
//    self.fliteController.target_mean = 1.0; // Reset the pitch
//    self.fliteController.target_stddev = 1.0; // Reset the variance
}

// An optional delegate method of OpenEarsEventsObserver which informs that the Pocketsphinx recognition loop has entered its actual loop.
// This might be useful in debugging a conflict between another sound class and Pocketsphinx.
- (void) pocketsphinxRecognitionLoopDidStart {
    
    NSLog(@"Pocketsphinx is starting up."); // Log it.
    self.textViewBelow.text = @"Status: Pocketsphinx is starting up."; // Show it in the status box.
}

// An optional delegate method of OpenEarsEventsObserver which informs that Pocketsphinx is now listening for speech.
- (void) pocketsphinxDidStartListening {
    
    NSLog(@"Pocketsphinx is now listening."); // Log it.
    self.textViewBelow.text = @"Status: Pocketsphinx is now listening."; // Show it in the status box.
    
    self.buttonStartListening.hidden = TRUE; // React to it with some UI changes.
    self.buttonStopListening.hidden = FALSE;
    self.buttonSuspendRecognition.hidden = FALSE;
    self.buttonResumeRecognition.hidden = TRUE;
}

// An optional delegate method of OpenEarsEventsObserver which informs that Pocketsphinx detected speech and is starting to process it.
- (void) pocketsphinxDidDetectSpeech {
    NSLog(@"Pocketsphinx has detected speech."); // Log it.
    self.textViewAbove.text = @"Status: Pocketsphinx has detected speech."; // Show it in the status box.
}

// An optional delegate method of OpenEarsEventsObserver which informs that Pocketsphinx detected a second of silence, indicating the end of an utterance.
// This was added because developers requested being able to time the recognition speed without the speech time. The processing time is the time between
// this method being called and the hypothesis being returned.
- (void) pocketsphinxDidDetectFinishedSpeech {
    NSLog(@"Pocketsphinx has detected a second of silence, concluding an utterance."); // Log it.
    self.textViewAbove.text = @"Status: Pocketsphinx has detected finished speech."; // Show it in the status box.
}


// An optional delegate method of OpenEarsEventsObserver which informs that Pocketsphinx has exited its recognition loop, most
// likely in response to the PocketsphinxController being told to stop listening via the stopListening method.
- (void) pocketsphinxDidStopListening {
    NSLog(@"Pocketsphinx has stopped listening."); // Log it.
    self.textViewAbove.text = @"Status: Pocketsphinx has stopped listening."; // Show it in the status box.
}

// An optional delegate method of OpenEarsEventsObserver which informs that Pocketsphinx is still in its listening loop but it is not
// Going to react to speech until listening is resumed.  This can happen as a result of Flite speech being
// in progress on an audio route that doesn't support simultaneous Flite speech and Pocketsphinx recognition,
// or as a result of the PocketsphinxController being told to suspend recognition via the suspendRecognition method.
- (void) pocketsphinxDidSuspendRecognition {
    NSLog(@"Pocketsphinx has suspended recognition."); // Log it.
    self.textViewAbove.text = @"Status: Pocketsphinx has suspended recognition."; // Show it in the status box.
}

// An optional delegate method of OpenEarsEventsObserver which informs that Pocketsphinx is still in its listening loop and after recognition
// having been suspended it is now resuming.  This can happen as a result of Flite speech completing
// on an audio route that doesn't support simultaneous Flite speech and Pocketsphinx recognition,
// or as a result of the PocketsphinxController being told to resume recognition via the resumeRecognition method.
- (void) pocketsphinxDidResumeRecognition {
    NSLog(@"Pocketsphinx has resumed recognition."); // Log it.
    self.textViewAbove.text = @"Status: Pocketsphinx has resumed recognition."; // Show it in the status box.
}

// An optional delegate method which informs that Pocketsphinx switched over to a new language model at the given URL in the course of
// recognition. This does not imply that it is a valid file or that recognition will be successful using the file.
- (void) pocketsphinxDidChangeLanguageModelToFile:(NSString *)newLanguageModelPathAsString andDictionary:(NSString *)newDictionaryPathAsString {
    NSLog(@"Pocketsphinx is now using the following language model: \n%@ and the following dictionary: %@",newLanguageModelPathAsString,newDictionaryPathAsString);
}

// An optional delegate method of OpenEarsEventsObserver which informs that Flite is speaking, most likely to be useful if debugging a
// complex interaction between sound classes. You don't have to do anything yourself in order to prevent Pocketsphinx from listening to Flite talk and trying to recognize the speech.
- (void) fliteDidStartSpeaking {
    NSLog(@"Flite has started speaking"); // Log it.
    self.textViewAbove.text = @"Status: Flite has started speaking."; // Show it in the status box.
}

// An optional delegate method of OpenEarsEventsObserver which informs that Flite is finished speaking, most likely to be useful if debugging a
// complex interaction between sound classes.
- (void) fliteDidFinishSpeaking {
    NSLog(@"Flite has finished speaking"); // Log it.
    self.textViewAbove.text = @"Status: Flite has finished speaking."; // Show it in the status box.
}

- (void) pocketSphinxContinuousSetupDidFail { // This can let you know that something went wrong with the recognition loop startup. Turn on [OpenEarsLogging startOpenEarsLogging] to learn why.
    NSLog(@"Setting up the continuous recognition loop has failed for some reason, please turn on [OpenEarsLogging startOpenEarsLogging] in OpenEarsConfig.h to learn more."); // Log it.
    self.textViewAbove.text = @"Status: Not possible to start recognition loop."; // Show it in the status box.
}

- (void) testRecognitionCompleted { // A test file which was submitted for direct recognition via the audio driver is done.
    NSLog(@"A test file which was submitted for direct recognition via the audio driver is done."); // Log it.
    [self.pocketsphinxController stopListening];
    
}
/** Pocketsphinx couldn't start because it has no mic permissions (will only be returned on iOS7 or later).*/
- (void) pocketsphinxFailedNoMicPermissions {
    NSLog(@"The user has never set mic permissions or denied permission to this app's mic, so listening will not start.");
    self.startupFailedDueToLackOfPermissions = TRUE;
}

/** The user prompt to get mic permissions, or a check of the mic permissions, has completed with a TRUE or a FALSE result  (will only be returned on iOS7 or later).*/
- (void) micPermissionCheckCompleted:(BOOL)result {
    if(result == TRUE) {
        self.restartAttemptsDueToPermissionRequests++;
        if(self.restartAttemptsDueToPermissionRequests == 1 && self.startupFailedDueToLackOfPermissions == TRUE) { // If we get here because there was an attempt to start which failed due to lack of permissions, and now permissions have been requested and they returned true, we restart exactly once with the new permissions.
            [self startListening]; // Only do this once.
            self.startupFailedDueToLackOfPermissions = FALSE;
        }
    }
}

#pragma mark -
#pragma mark UI

// This is not OpenEars-specific stuff, just some UI behavior

- (void) suspendListeningButtonAction { // This is the action for the button which suspends listening without ending the recognition loop
    [self.pocketsphinxController suspendRecognition];
    
    self.buttonStartListening.hidden = TRUE;
    self.buttonStopListening.hidden = FALSE;
    self.buttonSuspendRecognition.hidden = TRUE;
    self.buttonResumeRecognition.hidden = FALSE;
}

- (void) resumeListeningButtonAction { // This is the action for the button which resumes listening if it has been suspended
    [self.pocketsphinxController resumeRecognition];
    
    self.buttonStartListening.hidden = TRUE;
    self.buttonStopListening.hidden = FALSE;
    self.buttonSuspendRecognition.hidden = FALSE;
    self.buttonResumeRecognition.hidden = TRUE;
}

- (void) stopButtonAction { // This is the action for the button which shuts down the recognition loop.
    [self.pocketsphinxController stopListening];
    
    self.buttonStartListening.hidden = FALSE;
    self.buttonStopListening.hidden = TRUE;
    self.buttonSuspendRecognition.hidden = TRUE;
    self.buttonResumeRecognition.hidden = TRUE;
}

- (void) startButtonAction { // This is the action for the button which starts up the recognition loop again if it has been shut down.
    [self startListening];
    
    self.buttonStartListening.hidden = TRUE;
    self.buttonStopListening.hidden = FALSE;
    self.buttonSuspendRecognition.hidden = FALSE;
    self.buttonResumeRecognition.hidden = TRUE;
}

#pragma mark -
#pragma mark Example for reading out Pocketsphinx and Flite audio levels without locking the UI by using an NSTimer

// What follows are not OpenEars methods, just an approach for level reading
// that I've included with this sample app. My example implementation does make use of two OpenEars
// methods:	the pocketsphinxInputLevel method of PocketsphinxController and the fliteOutputLevel
// method of fliteController.
//
// The example is meant to show one way that you can read those levels continuously without locking the UI,
// by using an NSTimer, but the OpenEars level-reading methods
// themselves do not include multithreading code since I believe that you will want to design your own
// code approaches for level display that are tightly-integrated with your interaction design and the
// graphics API you choose.
//
// Please note that if you use my sample approach, you should pay attention to the way that the timer is always stopped in
// dealloc. This should prevent you from having any difficulties with deallocating a class due to a running NSTimer process.

- (void) startDisplayingLevels { // Start displaying the levels using a timer
    [self stopDisplayingLevels]; // We never want more than one timer valid so we'll stop any running timers first.
    self.uiUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/kLevelUpdatesPerSecond target:self selector:@selector(updateLevelsUI) userInfo:nil repeats:YES];
}

- (void) stopDisplayingLevels { // Stop displaying the levels by stopping the timer if it's running.
    if(self.uiUpdateTimer && [self.uiUpdateTimer isValid]) { // If there is a running timer, we'll stop it here.
        [self.uiUpdateTimer invalidate];
        self.uiUpdateTimer = nil;
    }
}

- (void) updateLevelsUI { // And here is how we obtain the levels.  This method includes the actual OpenEars methods and uses their results to update the UI of this view controller.
    
    self.labelInputLevel.text = [NSString stringWithFormat:@"Pocketsphinx Input level:%f",[self.pocketsphinxController pocketsphinxInputLevel]];  //pocketsphinxInputLevel is an OpenEars method of the class PocketsphinxController.
    
}

@end
