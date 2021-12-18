//
//  ContentView.swift
//  AXBugsWithCatalystApps
//
//  Created by Guillaume Leclerc on 18/12/2021.
//

import SwiftUI

struct ContentView: View {
    let axEngine = AXEngine()
    
    var body: some View {
        Form {
            Button("get AX info") {
                let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
                _ = AXIsProcessTrustedWithOptions(options)
                
                sleep(4)
                
                let axSystemWideElement = AXUIElementCreateSystemWide()
                
                var axFocusedElement: AnyObject?
                guard AXUIElementCopyAttributeValue(axSystemWideElement, kAXFocusedUIElementAttribute as CFString, &axFocusedElement) == .success else {
                    print("can't get system wide element")
                    
                    return                    
                }
                
                var axSelectedTextRange: AnyObject?
                guard AXUIElementCopyAttributeValue(axFocusedElement as! AXUIElement, kAXSelectedTextRangeAttribute as CFString, &axSelectedTextRange) == .success else {
                    print("can't get text range")
                    
                    return
                }
                
                var selectedTextRange = CFRange()
                AXValueGetValue(axSelectedTextRange as! AXValue, .cfRange, &selectedTextRange)
                
                var currentLine: AnyObject?
                guard AXUIElementCopyParameterizedAttributeValue(axFocusedElement as! AXUIElement, kAXLineForIndexParameterizedAttribute as CFString, selectedTextRange.location as CFTypeRef, &currentLine) == .success else {
                    print("can't get current line")
                    
                    return
                }
                
                var lineRangeValue: AnyObject?
                guard AXUIElementCopyParameterizedAttributeValue(axFocusedElement as! AXUIElement, kAXRangeForLineParameterizedAttribute as CFString, currentLine as CFTypeRef, &lineRangeValue) == .success else {
                    print("can't get line range")
                    
                    return
                }
                
                var lineRange = CFRange()
                AXValueGetValue(lineRangeValue as! AXValue, .cfRange, &lineRange)
                
                print(lineRange)
            }
        }
        .frame(width: 300, height: 300, alignment: .center)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
