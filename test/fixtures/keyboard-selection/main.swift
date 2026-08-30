import Foundation

let entries = ["apps", "learn", "trigger"]

guard OMacOSKeyboardSelection.movedID(currentID: nil, orderedIDs: entries, offset: 1) == "apps",
      OMacOSKeyboardSelection.movedID(currentID: nil, orderedIDs: entries, offset: -1) == "trigger",
      OMacOSKeyboardSelection.movedID(currentID: "apps", orderedIDs: entries, offset: 1) == "learn",
      OMacOSKeyboardSelection.movedID(currentID: "trigger", orderedIDs: entries, offset: 1) == "apps",
      OMacOSKeyboardSelection.movedID(currentID: "apps", orderedIDs: entries, offset: -1) == "trigger",
      OMacOSKeyboardSelection.movedID(currentID: nil, orderedIDs: [], offset: 1) == nil else {
    fputs("Keyboard selection navigation produced an unexpected entry.\n", stderr)
    exit(1)
}

print("Keyboard selection navigation test passed")
