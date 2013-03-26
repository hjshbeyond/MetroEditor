//
//  MapView.m
//  tube
//
//  Created by Alex 1 on 9/24/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "MapView.h"
#import "CityMap.h"
#import <Foundation/Foundation.h>
//#import "tubeAppDelegate.h"
#import "MyTiledLayer.h"
//#import "Schedule.h"
//#import "ManagedObjects.h"
#import "MEWindow.h"

@implementation MapView
@synthesize cityMap;
@synthesize selectedStationName;
@synthesize stationSelected;
@synthesize selectedStationLine;
@synthesize selectedStationLayer;
@synthesize selectedLocationLayer;
@synthesize Scale;
@synthesize MaxScale;
@synthesize MinScale;
@synthesize vcontroller;
@synthesize foundPaths;
@synthesize nearestStation;
@synthesize nearestStationName = nearestStationName;

+ (Class)layerClass
{
    return [MyTiledLayer class];
}

-(void) setTransform:(CGAffineTransform)transform
{
    super.transform = transform;
}

- (CGSize) size {
    return CGSizeMake(cityMap.w, cityMap.h);
}

-(NSColor*) backgroundColor
{
    return cityMap.backgroundColor;
}

-(DrawNameType) drawName
{
    return cityMap.drawName;
}

-(void) setDrawName:(DrawNameType)drawName
{
    if(drawName != cityMap.drawName) {
        cityMap.drawName = drawName;
    }
}

-(id)initWithCoder:(NSCoder *)aDecoder
{
    if((self = [super initWithCoder:aDecoder])) {
		//близжайщней станции пока нет
		nearestStationName = @"";
        MinScale = 0.25f;
        MaxScale = 4.f;
        Scale = 1.f;
        selectedStationName = [[NSMutableString alloc] init];
        selectedStations = [[NSMutableSet alloc] init];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        // Initialization code
        visualFrame = frame;

		//близжайщней станции пока нет
		nearestStationName = @"";
        MinScale = 0.25f;
        MaxScale = 4.f;
        Scale = 1.f;
        selectedStationName = [[NSMutableString alloc] init];
        selectedStations = [[NSMutableSet alloc] init];
    }
    return self;
}

-(void)setCityMap:(CityMap *)_cityMap
{
    cityMap = _cityMap;
    self.frame = CGRectMake(0, 0, cityMap.w, cityMap.h);
    MinScale = MIN( (float)visualFrame.size.width / cityMap.size.width, (float)visualFrame.size.height / cityMap.size.height);
    MaxScale = cityMap.maxScale;
    Scale = 1.f;//MinScale * 2.f;

    if(cityMap.backgroundImageFile != nil) {
        if(vectorLayer != nil) [vectorLayer loadFrom:cityMap.backgroundImageFile directory:cityMap.thisMapName];
        else vectorLayer = [[VectorLayer alloc] initWithFile:cityMap.backgroundImageFile andDir:cityMap.thisMapName];
    } else {
        vectorLayer = nil;
    }
    if(cityMap.foregroundImageFile != nil) {
        if(vectorLayer2 != nil) [vectorLayer2 loadFrom:cityMap.foregroundImageFile directory:cityMap.thisMapName];
        else vectorLayer2 = [[VectorLayer alloc] initWithFile:cityMap.foregroundImageFile andDir:cityMap.thisMapName];
    } else {
        vectorLayer2 = nil;
    }
}

-(void)drawRect:(CGRect)rect
{
    CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
    [self drawLayer:nil inContext:context];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)context {

    CGContextSaveGState(context);
    CGRect r = CGContextGetClipBoundingBox(context);
    CGFloat components[4];
    [self.backgroundColor getComponents:components];
	//CGContextSetFillColorWithColor(context, CGColorCreateGenericRGB(1.f, 1.f, 1.f, 1.f));
    CGContextSetRGBFillColor(context, *components, *(components+1), *(components+2), *(components+3));
	CGContextFillRect(context, r);

    CGContextRef ctx = context;

    CGContextSetInterpolationQuality(ctx, kCGInterpolationNone);
    CGContextSetShouldAntialias(ctx, true);
    CGContextSetShouldSmoothFonts(ctx, false);
    CGContextSetAllowsFontSmoothing(ctx, false);
    
    if(vectorLayer) [vectorLayer draw:context inRect:r];
    cityMap.currentScale = 1.f;//scrollView.zoomScale / MaxScale;
    [cityMap drawMap:ctx inRect:r];
    [cityMap drawTransfers:ctx inRect:r];
    if(vectorLayer2) [vectorLayer2 draw:context inRect:r];
    [cityMap drawStations:ctx inRect:r];
    if(makeSelection == SELECT_MULTI && CGRectIntersectsRect(r, multiSelectRect)) {
        drawSelectionRect(context, multiSelectRect);
    }

    CGContextRestoreGState(context);
}

#pragma mark -

- (void)viewDidLoad 
{
    //[super viewDidLoad];
}

- (void) drawString: (NSString*) s withFont: (NSFont*) font inRect: (CGRect) contextRect {
	
    CGFloat fontHeight = font.pointSize;
    CGFloat yOffset = (contextRect.size.height - fontHeight) / 2.0;
	
    CGRect textRect = CGRectMake(0, yOffset, contextRect.size.width, fontHeight);
	NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil];
    [s drawInRect:textRect withAttributes:attributes];
}

-(Station*)selectStationAt:(CGPoint*)currentPosition
{
    Station *s = [cityMap checkPoint:currentPosition Station:selectedStationName selectText:&selectText];
    if(s != nil) {
        selectedStationLine = s.line.index;
		stationSelected=true;
        //Line *l = [cityMap.mapLines objectAtIndex:selectedStationLine-1];
        return s;
    } else {
        stationSelected=false;
    }
    return nil;
}

-(Segment*)selectSegmentAt:(CGPoint*)currentPosition
{
    Segment *s = [cityMap checkPoint:currentPosition segmentPoint:&currentSegmentPoint];
    return s;
}

-(void)selectStationsByRect:(CGRect)r
{
    NSArray *a = [cityMap checkRect:r];
    for (Station *s in a) {
        s.active = YES;
    }
    [selectedStations addObjectsFromArray:a];
    [(MEWindow*)self.window selectStation:[a lastObject]];
}

-(void)adjustMap
{
}

-(void)keyDown:(NSEvent *)theEvent
{
}

-(void)keyUp:(NSEvent *)theEvent
{
}

-(void)mouseDown:(NSEvent *)theEvent
{
    NSPoint loc = [self convertPoint:theEvent.locationInWindow fromView:nil];
    CGPoint p = CGPointMake(loc.x, loc.y);
    NSUInteger mod = [NSEvent modifierFlags];
    if((mod & NSAlternateKeyMask) && (mod & NSShiftKeyMask)) {
        // combine two lines
        [self combineTwoLines:p];
    } else if(mod & NSShiftKeyMask) {
        // new station
        [self newStation:p];
    } else if (mod & NSAlternateKeyMask) {
        // new transfer element
        [self changeTransferAt:p];
    } else if (mod & NSControlKeyMask) {
        // new spline point
        [self newSplinePoint:p];
    } else {
        currentStation = [self selectStationAt:&p];
        if(currentStation == nil) {
            currentSegment = [self selectSegmentAt:&p];
        } else currentSegment = nil;
        makeSelection = SELECT_SINGLE;
    }
}

-(void)mouseDragged:(NSEvent *)theEvent
{
    if(makeSelection == SELECT_MULTI) {
        NSPoint loc = [self convertPoint:theEvent.locationInWindow fromView:nil];
        multiSelectRect.size = CGSizeMake(loc.x - multiSelectRect.origin.x, loc.y - multiSelectRect.origin.y);
        [self setNeedsDisplayInRect:[self visibleRect]];
        return;
    }
    if(currentSegment != nil) {
        CGPoint delta = CGPointMake(theEvent.deltaX / Scale, -theEvent.deltaY / Scale);
        [currentSegment movePoint:currentSegmentPoint by:delta];
        [self setNeedsDisplayInRect:[self visibleRect]];
        return;
    }
    if([NSEvent modifierFlags] & NSCommandKeyMask) {
        // zoom view
        CGFloat factor = -theEvent.deltaY;
        if(factor > 0) {
            factor = 1 + factor/100;
        } else {
            factor = 1 + factor/200;
        }
        MEWindow* w = (MEWindow*)self.window;
        [w scaleBy:factor];
        makeSelection = SELECT_NONE;
    } else {
        if(currentStation != nil && !currentStation.active) {
            // activate new station
            for (Station *s in selectedStations) {
                s.active = NO;
            }
            [selectedStations removeAllObjects];
            currentStation.active = YES;
            [selectedStations addObject:currentStation];
            [(MEWindow*)self.window selectStation:currentStation];
        } else if(currentStation == nil) {
            if(!([NSEvent modifierFlags] & NSCommandKeyMask)) {
                // CMD not pressed
                for (Station *s in selectedStations) {
                    s.active = NO;
                }
                [selectedStations removeAllObjects];
            }
            makeSelection = SELECT_MULTI;
            NSPoint loc = [self convertPoint:theEvent.locationInWindow fromView:nil];
            multiSelectRect.origin = CGPointMake(loc.x, loc.y);
            multiSelectRect.size = CGSizeZero;
            return;
        }
        CGPoint delta = CGPointMake(theEvent.deltaX / Scale, -theEvent.deltaY / Scale);
        if([selectedStations count] > 0) {
            for (Station *s in selectedStations) {
                if(selectText) [s moveTextBy:delta];
                else [s moveBy:delta];
            }
            [self setNeedsDisplayInRect:[self visibleRect]];
        }
        makeSelection = SELECT_NONE;
    }
}

-(void)mouseUp:(NSEvent *)theEvent
{
    if(currentSegment) {
        [currentSegment.start.line updateBoundingBox];
        [self updateMapSize];
    } else if(makeSelection == SELECT_SINGLE && currentStation != nil) {
        if(!([NSEvent modifierFlags] & NSCommandKeyMask)) {
            // CMD not pressed
            for (Station *s in selectedStations) {
                s.active = NO;
            }
            [selectedStations removeAllObjects];
            currentStation.active = YES;
            [selectedStations addObject:currentStation];
            [(MEWindow*)self.window selectStation:currentStation];
        } else {
            // CMD pressed
            if(currentStation.active) {
                currentStation.active = NO;
                [selectedStations removeObject:currentStation];
                [(MEWindow*)self.window selectStation:[selectedStations anyObject]];
            } else {
                currentStation.active = YES;
                [selectedStations addObject:currentStation];
                [(MEWindow*)self.window selectStation:currentStation];
            }
        }
    } else if(makeSelection == SELECT_SINGLE && currentStation == nil && [selectedStations count] > 0) {
        for (Station *s in selectedStations) {
            s.active = NO;
        }
        [selectedStations removeAllObjects];
        [(MEWindow*)self.window selectStation:nil];
    } else if(makeSelection == SELECT_MULTI) {
        [self selectStationsByRect:multiSelectRect];
        multiSelectRect = CGRectZero;
        [self setNeedsDisplayInRect:[self visibleRect]];
    } else if(makeSelection == SELECT_NONE) {
        NSMutableSet *lines = [NSMutableSet set];
        for (Station *s in selectedStations) {
            [lines addObject:s.line];
        }
        for (Line *l in lines) {
            [l updateBoundingBox];
        }
        [self updateMapSize];
    }
    makeSelection = SELECT_NONE;
    currentStation = nil;
    currentSegment = nil;
    currentSegmentPoint = 0;
}

-(void)alignHorizontal
{
    CGPoint center = CGPointZero;
    for (Station *s in selectedStations) {
        center.y += s.pos.y;
    }
    center.y /= [selectedStations count];
    for (Station *s in selectedStations) {
        [s moveBy:CGPointMake(0, center.y-s.pos.y)];
    }
    [self setNeedsDisplayInRect:[self visibleRect]];
}

-(void)alignVertical
{
    CGPoint center = CGPointZero;
    for (Station *s in selectedStations) {
        center.x += s.pos.x;
    }
    center.x /= [selectedStations count];
    for (Station *s in selectedStations) {
        [s moveBy:CGPointMake(center.x-s.pos.x, 0)];
    }
    [self setNeedsDisplayInRect:[self visibleRect]];
}

-(void) updateMapSize
{
    [cityMap updateBoundingBox];
    self.frame = CGRectMake(0, 0, cityMap.w, cityMap.h);
    self.bounds = self.frame;
    NSScrollView *sv = (NSScrollView*)self.superview;
    [sv.documentView scaleUnitSquareToSize:NSMakeSize(Scale, Scale)];
    [sv.documentView setFrameSize: CGSizeMake(cityMap.w * Scale, cityMap.h * Scale) ];
}

-(void) newStation:(CGPoint)p
{
    MEWindow *wnd = (MEWindow*)self.window;
    Station *ss = wnd.selectedStation;
    NSUInteger si = 0;
    CGRect tr = CGRectMake(p.x+50, p.y+50, 400, 100);
    if(ss != nil) {
        si = [ss.line.stations count];
    }
    Station *ns = [[Station alloc] initWithMap:cityMap name:@"New Station" pos:p index:(int)si rect:tr andDriving:@""];
    if(ss != nil) {
        [ss.line.stations addObject:ns];
        ns.line = ss.line;
        [ss.segment addObject:[[Segment alloc] initFromStation:ss toStation:ns withDriving:1]];
        [[ss.segment lastObject] prepare];
        [ss.line updateBoundingBox];
    } else {
        // make new line
        Line *l = [[Line alloc] initWithMap:cityMap andName:@"New Line"];
        l.index = [cityMap.mapLines count];
        l.color = [NSColor blueColor];
        l.pinColor = 0;
        [cityMap.mapLines addObject:l];
        [l.stations addObject:ns];
        ns.line = l;
        [l updateBoundingBox];
    }
    ns.active = YES;
    [selectedStations addObject:ns];
    [wnd selectStation:ns];
    [cityMap updateBoundingBox];
    [self setNeedsDisplayInRect:[self visibleRect]];
}

-(void) newSplinePoint:(CGPoint)p
{
    Station *s1 = ((MEWindow*)self.window).selectedStation;
    Segment *ss = [self selectSegmentAt:&p];
    if(ss != nil) {
        [ss removePoint:currentSegmentPoint];
        [ss prepare];
        currentSegmentPoint = 0;
        currentSegment = nil;
        [self setNeedsDisplayInRect:[self visibleRect]];
        return;
    }
    for (Segment *seg in s1.segment) {
        if([selectedStations containsObject:seg.end]) {
            ss = seg;
            break;
        }
    }
    if(ss == nil) for (Segment *seg in s1.backSegment) {
        if([selectedStations containsObject:seg.start]) {
            ss = seg;
            break;
        }
    }
    if(ss != nil) {
        [ss appendPoint:p];
        [ss prepare];
        [self setNeedsDisplayInRect:[self visibleRect]];
    }
}

-(void)changeTransferAt:(CGPoint)p
{
    Transfer *tr = nil;
    currentStation = [self selectStationAt:&p];
    if(currentStation.transfer != nil) {
        tr = currentStation.transfer;
        [tr removeStation:currentStation];
        if([tr.stations count] <= 0) {
            [cityMap.transfers removeObject:tr];
        }
        currentStation.active = NO;
        [selectedStations removeObject:currentStation];
    } else {
        for (Station *s in selectedStations) {
            if(s.transfer != nil) {
                tr = s.transfer;
                break;
            }
        }
        currentStation.active = YES;
        [selectedStations addObject:currentStation];
        if(tr != nil) {
            [tr addStation:currentStation];
        } else {
            tr = [[Transfer alloc] initWithMap:cityMap];
            for (Station *s in selectedStations) {
                [tr addStation:s];
            }
            [cityMap.transfers addObject:tr];
        }
        [((MEWindow*)self.window) selectStation:currentStation];
    }
}

-(void)combineTwoLines:(CGPoint)p
{
    currentStation = [self selectStationAt:&p];
    Station *s1 = ((MEWindow*)self.window).selectedStation;
    Line *l1 = s1.line;
    Line *l2 = currentStation.line;
    if(l1 != l2) {
        for (Station *s in l2.stations) {
            s.line = l1;
        }
        [l1.stations addObjectsFromArray:l2.stations];
        Segment *seg = [[Segment alloc] initFromStation:s1 toStation:currentStation withDriving:1];
        [seg prepare];
        [s1.segment addObject:seg];
        [l2.stations removeAllObjects];
        [cityMap.mapLines removeObject:l2];
    }
}

@end
