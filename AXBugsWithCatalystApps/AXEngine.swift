import SwiftUI


public struct AXTextElementData {
    
    public let role: AXElementRole
    public let value: String
    public let length: Int
    public let caretLocation: Int
    public let selectedLength: Int
    public let selectedText: String
    
}


public enum AXElementRole {
    
    case comboBox
    case scrollArea
    case textField
    case textArea
    case webArea
    case someOtherShit
    
}


public protocol AccessibilityTextElementProtocol {
    
    var role: AXElementRole { get }
    var caretLocation: Int { get }
    var selectedLength: Int { get }
    var selectedText: String? { get }
    var length: Int { get }
    
}


public protocol AXEngineProtocol {
    
    func axRole(of axFocusedElement: AXUIElement?) -> AXElementRole?

}


public extension AXEngineProtocol {
    
    func axRole() -> AXElementRole? {
        return axRole(of: AXEngine().axFocusedElement())
    }
    
}


public struct AXEngine: AXEngineProtocol {
    
    public init() {}
    
    
    public func axFocusedElement() -> AXUIElement? {
        let axSystemWideElement = AXUIElementCreateSystemWide()
        
        var axFocusedElement: AnyObject?
        let error = AXUIElementCopyAttributeValue(axSystemWideElement, kAXFocusedUIElementAttribute as CFString, &axFocusedElement)
        
        
        return axFocusedElement as! AXUIElement?
    }
    
    public func axLineNumberFor(location: Int, on axFocusedElement: AXUIElement? = AXEngine().axFocusedElement()) -> Int? {
        guard let axFocusedElement = axFocusedElement else { return nil }
        
        var currentLine: AnyObject?
        guard AXUIElementCopyParameterizedAttributeValue(axFocusedElement, kAXLineForIndexParameterizedAttribute as CFString, location as CFTypeRef, &currentLine) == .success else { return nil }
        
        return (currentLine as! Int)
    }
    
    public func axLineRangeFor(lineNumber: Int, on axFocusedElement: AXUIElement? = AXEngine().axFocusedElement()) -> CFRange? {
        guard let axFocusedElement = axFocusedElement else { return nil }
        
        var lineRangeValue: AnyObject?
        guard AXUIElementCopyParameterizedAttributeValue(axFocusedElement, kAXRangeForLineParameterizedAttribute as CFString, lineNumber as CFTypeRef, &lineRangeValue) == .success else { return nil }
        
        var lineRange = CFRange()
        AXValueGetValue(lineRangeValue as! AXValue, .cfRange, &lineRange)
        
        // to cope with a AX API bug that affects TextAreas in browsers
        // axLineRangeFor should return nil when on a last line but in browsers.
        // it returns a line of location 0 and length 0. bad.
        // reported as FB9796727.
        if lineRange.location == 0, lineRange.length == 0, lineNumber > 1 { return nil }
        
        // TODO: see more, and report to Apple once we start supporting AX for Catalyst Apps
//        if lineRange.location == 2147483647 {
//            guard let (_, elementLength) = axValueAndNumberOfCharacters(of: axFocusedElement) else { return nil }
//
//            return CFRange(location: 0, length: elementLength)
//        }

        return lineRange
    }
    
    public func axRole(of axFocusedElement: AXUIElement? = AXEngine().axFocusedElement()) -> AXElementRole? {
        guard let axFocusedElement = axFocusedElement else { return nil }
        
        var role: AnyObject?
        let error = AXUIElementCopyAttributeValue(axFocusedElement, kAXRoleAttribute as CFString, &role)
        
        guard error == .success, let elementRole = role as? String else { return nil }
        
        return self.role(for: elementRole)
    }
    
    public func axTextElementData(of axFocusedElement: AXUIElement? = AXEngine().axFocusedElement()) -> AXTextElementData? {
        guard let axFocusedElement = axFocusedElement else { return nil }
        
        // had to remove kAXSelectedTextAttribute because sometimes input fields that should send
        // an empty string are sending nil instead and make the AX func fail (e.g. Twitter). we now grab the kAXSelectedTextAttribute
        // later and if nil we map it to an empty string and hooray we can keep going. 
        var values: CFArray?
        let error = AXUIElementCopyMultipleAttributeValues(axFocusedElement, [kAXRoleAttribute, kAXValueAttribute, kAXNumberOfCharactersAttribute, kAXSelectedTextRangeAttribute] as CFArray, .stopOnError, &values)
        
        guard error == .success, let elementValues = values as NSArray? else { return nil }
        
        let axRole = role(for: elementValues[0] as! String)
        guard axRole != .someOtherShit else { return nil }
        
        // as said above. this can be nil (Twee'ahhh), which we will replace then by an empty string later.
        var selectedText: AnyObject?
        AXUIElementCopyAttributeValue(axFocusedElement, kAXSelectedTextAttribute as CFString, &selectedText)
        
        var selectedTextRange = CFRange()
        AXValueGetValue(elementValues[3] as! AXValue, .cfRange, &selectedTextRange)
        
        // there's issues with the AX API and Catalyst apps. the AX returns success but the axValue
        // and axLength are nil sometimes. so we need to be extra careful. happens in iMessage,
        // Maps, Podcasts (but not Music).
        guard let axValue = elementValues[1] as? String else { return nil }
        guard let axLength = elementValues[2] as? Int else { return nil }
        let axCaretLocation = selectedTextRange.location
        let axSelectedLength = selectedTextRange.length
        let axSelectedText = selectedText as? String ?? "" 
        
        return AXTextElementData(
            role: axRole,
            value: axValue,
            length: axLength,
            caretLocation: axCaretLocation,
            selectedLength: axSelectedLength,
            selectedText: axSelectedText
        )
    }
    
    private func role(for role: String) -> AXElementRole {
        switch (role) {
        case "AXComboBox":
            return .comboBox
        case "AXScrollArea":
            return .scrollArea
        case "AXTextField":
            return .textField
        case "AXTextArea":
            return .textArea
        case "AXWebArea":
            return .webArea
        default:
            return .someOtherShit
        }
    }
    
    func axSelectedTextRange(on axFocusedElement: AXUIElement? = AXEngine().axFocusedElement()) -> CFRange? {
        guard let axFocusedElement = axFocusedElement else { return nil }
        
        var axSelectedTextRange: AnyObject?
        guard AXUIElementCopyAttributeValue(axFocusedElement, kAXSelectedTextRangeAttribute as CFString, &axSelectedTextRange) == .success else { return nil }
        
        var selectedTextRange = CFRange()
        AXValueGetValue(axSelectedTextRange as! AXValue, .cfRange, &selectedTextRange)
        
        return selectedTextRange
    }
    
    public func axValueAndNumberOfCharacters(of axFocusedElement: AXUIElement? = AXEngine().axFocusedElement()) -> (String, Int)? {
        guard let axFocusedElement = axFocusedElement else { return nil }
        
        var values: CFArray?
        let error = AXUIElementCopyMultipleAttributeValues(axFocusedElement, [kAXRoleAttribute, kAXValueAttribute, kAXNumberOfCharactersAttribute] as CFArray, .stopOnError, &values)
        
        guard error == .success, let elementValues = values as NSArray? else { return nil }
        
        guard role(for: elementValues[0] as! String) != .someOtherShit else { return nil }
        
        guard let axValue = elementValues[1] as? String else { return nil }
        guard let axLength = elementValues[2] as? Int else { return nil }
        
        return (axValue, axLength)
    }
    
    public func axFullScreenStatusOfFocusedWindow() -> Bool {
        guard let processIdentifier = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return false }
        
        let axApplicationElement = AXUIElementCreateApplication(processIdentifier)
        
        var axFocusedWindow: AnyObject?
        guard AXUIElementCopyAttributeValue(axApplicationElement, kAXFocusedWindowAttribute as CFString, &axFocusedWindow) == .success else { return false }
        
        var fullScreenStatus: AnyObject?
        guard AXUIElementCopyAttributeValue(axFocusedWindow as! AXUIElement, "AXFullScreen" as CFString, &fullScreenStatus) == .success else { return false }
        
        return fullScreenStatus as! Bool
    }
    
    public func toAXFocusedElement(from accessibilityElement: AccessibilityTextElementProtocol, visibleCharacterLocation: Int) -> Bool {
        guard let axFocusedElement = axFocusedElement() else { return false }
        
        var visibleCharacterRange = CFRange()
        visibleCharacterRange.location = visibleCharacterLocation
        visibleCharacterRange.length = 0

        let newVisibleCharacterRange = AXValueCreate(.cfRange, &visibleCharacterRange)
        AXUIElementSetAttributeValue(axFocusedElement, kAXVisibleCharacterRangeAttribute as CFString, newVisibleCharacterRange as CFTypeRef)
        
        var selectedTextRange = CFRange()
        selectedTextRange.location = accessibilityElement.caretLocation
        selectedTextRange.length = accessibilityElement.selectedLength
        
        let newValue = AXValueCreate(.cfRange, &selectedTextRange)
        guard AXUIElementSetAttributeValue(axFocusedElement, kAXSelectedTextRangeAttribute as CFString, newValue!) == .success else { return false }
        
        if let selectedText = accessibilityElement.selectedText {
            guard AXUIElementSetAttributeValue(axFocusedElement, kAXSelectedTextAttribute as CFString, selectedText as CFTypeRef) == .success else { return false }
        }
       
        return true
    }

    private func updatedVisibleCharacterRangeIfNecessary(for element: AccessibilityTextElementProtocol, with visibleCharacterLocation: Int, using axFocusedElement: AXUIElement) -> CFRange? {
        switch element.role {
        case .textField:
            return updatedVisibleCharacterRangeForTextFields(with: visibleCharacterLocation)
        default:
            return updatedVisibleCharacterRangeForOtherElements(with: visibleCharacterLocation, using: axFocusedElement)
        }
    }
    
    // currently the 3 Visible Character Range funcs below are not used anymore. we force the visible range
    // according to caret location or VM head. but i leave it there for now to remind me of why we
    // went the way we went. AX API is hard and full of bugs. very hard to get something consistent.
    
    // the visibleCharacterRange returned by Apple's AX API doesn't work for TextFields (returns the whole field from start
    // to end instead).
    // so we need to trick by constantly moving the visibleCharacterRange one character before the location, except if
    // we're already at the beginning.
    // also to move at the right time we need to use a length of 3, but not when we're at the last character else it fails LOL
    private func updatedVisibleCharacterRangeForTextFields(with visibleCharacterLocation: Int) -> CFRange {
        return CFRange(
            location: visibleCharacterLocation,
            length: 0
        )
    }
    
    // the visibleCharacterRange is tricky also for TextAreas because some also return the whole field from start to end instead
    // of the visible part ROFL.
    // so in those cases, we have to ignore and not set the visibleCharacterRange, else the buffer will keep flickering :(
    // what a big pile of fucking shit Apple.
    private func updatedVisibleCharacterRangeForOtherElements(with visibleCharacterLocation: Int, using axFocusedElement: AXUIElement) -> CFRange? {
        guard let visibleCharacterRange = axVisibleCharacterRange(for: axFocusedElement) else { return nil }
       
        // NM or Head before Anchor
        if visibleCharacterLocation <= visibleCharacterRange.location {
            return CFRange(
                location: visibleCharacterLocation,
                length: 0
            )
        }
        
        // Head after Anchor
        if visibleCharacterLocation >= visibleCharacterRange.location + visibleCharacterRange.length {
            return CFRange(
                location: visibleCharacterLocation,
                length: 0
            )
        }
        
        return nil
    }
    
    private func axVisibleCharacterRange(for axFocusedElement: AXUIElement? = AXEngine().axFocusedElement()) -> CFRange? {
        guard let axFocusedElement = axFocusedElement else { return nil }
        
        var axVisibleCharacterRange: AnyObject?
        guard AXUIElementCopyAttributeValue(axFocusedElement, kAXVisibleCharacterRangeAttribute as CFString, &axVisibleCharacterRange) == .success else { return nil }
        
        
        var visibleCharacterRange = CFRange()
        AXValueGetValue(axVisibleCharacterRange as! AXValue, .cfRange, &visibleCharacterRange)
        
        return visibleCharacterRange
    }
    
}
